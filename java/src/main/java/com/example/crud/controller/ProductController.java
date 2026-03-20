package com.example.crud.controller;

import com.example.crud.model.Product;
import com.example.crud.repository.ProductRepository;
import datadog.trace.api.Trace;
import io.opentracing.Span;
import io.opentracing.util.GlobalTracer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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

    @GetMapping("/health")
    public ResponseEntity<?> health() {
        return ResponseEntity.ok(Map.of("status","ok","service","java-crud","version","1.0.0"));
    }

    @GetMapping("/products")
    @Trace(operationName = "products.list", resourceName = "GET /products")
    public ResponseEntity<List<Product>> listProducts() {
        Span span = GlobalTracer.get().activeSpan();
        List<Product> products = repository.findAll();
        if (span != null) span.setTag("results.count", products.size());
        log.info("Listed {} products", products.size());
        return ResponseEntity.ok(products);
    }

    @GetMapping("/products/{id}")
    @Trace(operationName = "products.get", resourceName = "GET /products/{id}")
    public ResponseEntity<Product> getProduct(@PathVariable Long id) {
        Span span = GlobalTracer.get().activeSpan();
        if (span != null) span.setTag("product.id", id);
        return repository.findById(id).map(ResponseEntity::ok).orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/products")
    @Trace(operationName = "products.create", resourceName = "POST /products")
    public ResponseEntity<Product> createProduct(@RequestBody Product product) {
        Span span = GlobalTracer.get().activeSpan();
        if (product.getCategory() == null) product.setCategory("general");
        if (product.getStock() == null) product.setStock(0);
        Product saved = repository.save(product);
        if (span != null) { span.setTag("product.id", saved.getId()); span.setTag("product.name", saved.getName()); }
        log.info("Created product id={} name={}", saved.getId(), saved.getName());
        return ResponseEntity.status(HttpStatus.CREATED).body(saved);
    }

    @PutMapping("/products/{id}")
    @Trace(operationName = "products.update", resourceName = "PUT /products/{id}")
    public ResponseEntity<Product> updateProduct(@PathVariable Long id, @RequestBody Product updated) {
        Span span = GlobalTracer.get().activeSpan();
        if (span != null) span.setTag("product.id", id);
        return repository.findById(id).map(existing -> {
            if (updated.getName()     != null) existing.setName(updated.getName());
            if (updated.getCategory() != null) existing.setCategory(updated.getCategory());
            if (updated.getPrice()    != null) existing.setPrice(updated.getPrice());
            if (updated.getStock()    != null) existing.setStock(updated.getStock());
            log.info("Updated product id={}", id);
            return ResponseEntity.ok(repository.save(existing));
        }).orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/products/{id}")
    @Trace(operationName = "products.delete", resourceName = "DELETE /products/{id}")
    public ResponseEntity<?> deleteProduct(@PathVariable Long id) {
        Span span = GlobalTracer.get().activeSpan();
        if (span != null) span.setTag("product.id", id);
        if (!repository.existsById(id)) return ResponseEntity.notFound().build();
        repository.deleteById(id);
        log.info("Deleted product id={}", id);
        return ResponseEntity.ok(Map.of("message", "Product " + id + " deleted"));
    }
}
