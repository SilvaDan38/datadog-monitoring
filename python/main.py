# main.py — Python CRUD com Datadog APM + DBM + Security
# FastAPI + SQLAlchemy + PostgreSQL + ddtrace

from dotenv import load_dotenv
load_dotenv()  # carrega .env antes de tudo

# ddtrace-run injeta o tracer automaticamente.
# Importamos apenas o tracer para spans manuais.
from ddtrace import tracer

from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List
import os
import logging

# ─── Logging ──────────────────────────────────────────────────────────────────
FORMAT = "%(asctime)s %(levelname)s [%(name)s] - %(message)s"
logging.basicConfig(format=FORMAT)
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# ─── Config ───────────────────────────────────────────────────────────────────
DB_URL = os.getenv("DATABASE_URL", "postgresql://crud_user:crud_pass@localhost:5432/crud_db")

# ─── SQLAlchemy ───────────────────────────────────────────────────────────────
engine = create_engine(DB_URL, echo=False)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


class Product(Base):
    __tablename__ = "products"
    id         = Column(Integer, primary_key=True, index=True)
    name       = Column(String(100), nullable=False)
    category   = Column(String(50))
    price      = Column(Float, nullable=False)
    stock      = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


Base.metadata.create_all(bind=engine)

# ─── FastAPI App ──────────────────────────────────────────────────────────────
# Não adicionamos TraceMiddleware manualmente — ddtrace-run já instrumenta o
# FastAPI/ASGI automaticamente via auto-instrumentação.
app = FastAPI(
    title="Python CRUD — Datadog Demo",
    description="CRUD com APM, DBM, CNM e Security via Datadog",
    version="1.0.0"
)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


# ─── Schemas ──────────────────────────────────────────────────────────────────
class ProductCreate(BaseModel):
    name: str
    category: Optional[str] = "general"
    price: float
    stock: int = 0

class ProductUpdate(BaseModel):
    name: Optional[str] = None
    category: Optional[str] = None
    price: Optional[float] = None
    stock: Optional[int] = None

class ProductResponse(BaseModel):
    id: int
    name: str
    category: Optional[str]
    price: float
    stock: int
    created_at: datetime
    updated_at: datetime
    class Config:
        from_attributes = True


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ─── Endpoints ────────────────────────────────────────────────────────────────

@app.get("/health")
def health_check():
    return {"status": "ok", "service": "python-crud", "version": "1.0.0"}


@app.get("/products", response_model=List[ProductResponse])
def list_products(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    with tracer.trace("products.list", resource="GET /products") as span:
        products = db.query(Product).offset(skip).limit(limit).all()
        span.set_tag("results.count", len(products))
        logger.info(f"Listed {len(products)} products")
        return products


@app.get("/products/{product_id}", response_model=ProductResponse)
def get_product(product_id: int, db: Session = Depends(get_db)):
    with tracer.trace("products.get", resource=f"GET /products/{product_id}") as span:
        span.set_tag("product.id", product_id)
        product = db.query(Product).filter(Product.id == product_id).first()
        if not product:
            span.set_tag("error", True)
            raise HTTPException(status_code=404, detail="Product not found")
        return product


@app.post("/products", response_model=ProductResponse, status_code=201)
def create_product(payload: ProductCreate, db: Session = Depends(get_db)):
    with tracer.trace("products.create", resource="POST /products") as span:
        span.set_tag("product.name", payload.name)
        span.set_tag("product.price", payload.price)
        product = Product(**payload.dict())
        db.add(product)
        db.commit()
        db.refresh(product)
        span.set_tag("product.id", product.id)
        logger.info(f"Created product id={product.id} name={product.name}")
        return product


@app.put("/products/{product_id}", response_model=ProductResponse)
def update_product(product_id: int, payload: ProductUpdate, db: Session = Depends(get_db)):
    with tracer.trace("products.update", resource=f"PUT /products/{product_id}") as span:
        span.set_tag("product.id", product_id)
        product = db.query(Product).filter(Product.id == product_id).first()
        if not product:
            raise HTTPException(status_code=404, detail="Product not found")
        update_data = {k: v for k, v in payload.dict().items() if v is not None}
        for key, value in update_data.items():
            setattr(product, key, value)
        product.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(product)
        logger.info(f"Updated product id={product_id}")
        return product


@app.delete("/products/{product_id}")
def delete_product(product_id: int, db: Session = Depends(get_db)):
    with tracer.trace("products.delete", resource=f"DELETE /products/{product_id}") as span:
        span.set_tag("product.id", product_id)
        product = db.query(Product).filter(Product.id == product_id).first()
        if not product:
            raise HTTPException(status_code=404, detail="Product not found")
        db.delete(product)
        db.commit()
        logger.info(f"Deleted product id={product_id}")
        return {"message": f"Product {product_id} deleted"}


# ─── Métricas customizadas (StatsD) — requer Datadog Agent rodando ────────────
try:
    from datadog import initialize, statsd as dd_statsd
    initialize(
        statsd_host=os.getenv("DD_AGENT_HOST", "localhost"),
        statsd_port=int(os.getenv("DD_DOGSTATSD_PORT", "8125"))
    )
    _statsd_available = True
except Exception:
    _statsd_available = False


@app.get("/metrics/test")
def test_metrics():
    if not _statsd_available:
        return {"message": "StatsD indisponível — Datadog Agent não está rodando"}
    dd_statsd.increment("crud.test.counter", tags=["service:python-crud", "env:local"])
    dd_statsd.gauge("crud.products.active", 42, tags=["service:python-crud"])
    return {"message": "Metrics enviadas ao Datadog"}