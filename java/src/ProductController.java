package com.example.crud.controller;

import com.example.crud.model.Product;
import com.example.crud.repository.ProductRepository;
import datadog.trace.api.Trace;
import io.opentracing.Span;
import io.opentracing.util.GlobalTracer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping
public class ProductController {

    private static final Logger log = LoggerFactory.getLogger(ProductController.class);

    @Autowired
    private ProductRepository repository;

    // ─── Utilitário: adiciona contexto do trace no MDC para correlação ─────────
    private void enrichMDC(Span span, String operation) {
        if (span != null) {
            MDC.put("dd.trace_id",  String.valueOf(span.context().toTraceId()));
            MDC.put("dd.span_id",   String.valueOf(span.context().toSpanId()));
        }
        MDC.put("operation", operation);
    }

    // ─── Health ───────────────────────────────────────────────────────────────
    @GetMapping("/health")
    public ResponseEntity<?> health() {
        log.info("Health check requested");
        return ResponseEntity.ok(Map.of(
            "status",  "ok",
            "service", "java-crud",
            "version", "1.0.1"
        ));
    }

    // ─── GET /products ────────────────────────────────────────────────────────
    @GetMapping("/products")
    @Trace(operationName = "products.list", resourceName = "GET /products")
    public ResponseEntity<List<Product>> listProducts() {
        Span span = GlobalTracer.get().activeSpan();
        enrichMDC(span, "products.list");
        try {
            List<Product> products = repository.findAll();
            if (span != null) span.setTag("results.count", products.size());
            log.info("Products listed successfully count={}", products.size());
            return ResponseEntity.ok(products);
        } catch (Exception e) {
            log.error("Failed to list products error={}", e.getMessage(), e);
            if (span != null) {
                span.setTag("error", true);
                span.setTag("error.message", e.getMessage());
            }
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        } finally {
            MDC.remove("operation");
        }
    }

    // ─── GET /products/{id} ───────────────────────────────────────────────────
    @GetMapping("/products/{id}")
    @Trace(operationName = "products.get", resourceName = "GET /products/{id}")
    public ResponseEntity<Product> getProduct(@PathVariable Long id) {
        Span span = GlobalTracer.get().activeSpan();
        enrichMDC(span, "products.get");
        try {
            if (span != null) span.setTag("product.id", id);
            return repository.findById(id)
                .map(p -> {
                    log.info("Product found id={} name={}", p.getId(), p.getName());
                    return ResponseEntity.ok(p);
                })
                .orElseGet(() -> {
                    log.warn("Product not found id={}", id);
                    if (span != null) span.setTag("error", true);
                    return ResponseEntity.notFound().build();
                });
        } finally {
            MDC.remove("operation");
        }
    }

    // ─── POST /products ───────────────────────────────────────────────────────
    @PostMapping("/products")
    @Trace(operationName = "products.create", resourceName = "POST /products")
    public ResponseEntity<Product> createProduct(@RequestBody Product product) {
        Span span = GlobalTracer.get().activeSpan();
        enrichMDC(span, "products.create");
        try {
            if (product.getName() == null || product.getName().isBlank()) {
                log.warn("Create rejected: name is required");
                return ResponseEntity.badRequest().build();
            }
            if (product.getPrice() == null || product.getPrice() <= 0) {
                log.warn("Create rejected: invalid price={}", product.getPrice());
                return ResponseEntity.badRequest().build();
            }
            if (product.getCategory() == null) product.setCategory("general");
            if (product.getStock()    == null) product.setStock(0);

            Product saved = repository.save(product);

            if (span != null) {
                span.setTag("product.id",       saved.getId());
                span.setTag("product.name",     saved.getName());
                span.setTag("product.price",    saved.getPrice());
                span.setTag("product.category", saved.getCategory());
            }
            log.info("Product created id={} name={} price={} category={}",
                saved.getId(), saved.getName(), saved.getPrice(), saved.getCategory());
            return ResponseEntity.status(HttpStatus.CREATED).body(saved);
        } catch (Exception e) {
            log.error("Failed to create product error={}", e.getMessage(), e);
            if (span != null) {
                span.setTag("error", true);
                span.setTag("error.message", e.getMessage());
            }
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        } finally {
            MDC.remove("operation");
        }
    }

    // ─── PUT /products/{id} ───────────────────────────────────────────────────
    @PutMapping("/products/{id}")
    @Trace(operationName = "products.update", resourceName = "PUT /products/{id}")
    public ResponseEntity<Product> updateProduct(
            @PathVariable Long id, @RequestBody Product updated) {
        Span span = GlobalTracer.get().activeSpan();
        enrichMDC(span, "products.update");
        try {
            if (span != null) span.setTag("product.id", id);
            return repository.findById(id).map(existing -> {
                if (updated.getName()     != null) existing.setName(updated.getName());
                if (updated.getCategory() != null) existing.setCategory(updated.getCategory());
                if (updated.getPrice()    != null) existing.setPrice(updated.getPrice());
                if (updated.getStock()    != null) existing.setStock(updated.getStock());
                Product saved = repository.save(existing);
                log.info("Product updated id={} name={} price={}",
                    saved.getId(), saved.getName(), saved.getPrice());
                return ResponseEntity.ok(saved);
            }).orElseGet(() -> {
                log.warn("Product not found for update id={}", id);
                if (span != null) span.setTag("error", true);
                return ResponseEntity.notFound().build();
            });
        } catch (Exception e) {
            log.error("Failed to update product id={} error={}", id, e.getMessage(), e);
            if (span != null) {
                span.setTag("error", true);
                span.setTag("error.message", e.getMessage());
            }
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        } finally {
            MDC.remove("operation");
        }
    }

    // ─── DELETE /products/{id} ────────────────────────────────────────────────
    @DeleteMapping("/products/{id}")
    @Trace(operationName = "products.delete", resourceName = "DELETE /products/{id}")
    public ResponseEntity<?> deleteProduct(@PathVariable Long id) {
        Span span = GlobalTracer.get().activeSpan();
        enrichMDC(span, "products.delete");
        try {
            if (span != null) span.setTag("product.id", id);
            if (!repository.existsById(id)) {
                log.warn("Product not found for delete id={}", id);
                if (span != null) span.setTag("error", true);
                return ResponseEntity.notFound().build();
            }
            repository.deleteById(id);
            log.info("Product deleted id={}", id);
            return ResponseEntity.ok(Map.of("message", "Product " + id + " deleted"));
        } catch (Exception e) {
            log.error("Failed to delete product id={} error={}", id, e.getMessage(), e);
            if (span != null) {
                span.setTag("error", true);
                span.setTag("error.message", e.getMessage());
            }
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        } finally {
            MDC.remove("operation");
        }
    }
}