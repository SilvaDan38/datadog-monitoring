# app.rb — Ruby CRUD com Datadog APM + DBM + Security
# Sinatra + ActiveRecord + PostgreSQL + ddtrace

# ─── Datadog — DEVE ser requerido antes de tudo ───────────────────────────────
require 'datadog'
require 'datadog/auto_instrument'  # auto-instrumenta Sinatra, ActiveRecord, etc.

Datadog.configure do |c|
  c.service  = ENV.fetch('DD_SERVICE', 'ruby-crud')
  c.env      = ENV.fetch('DD_ENV', 'local')
  c.version  = ENV.fetch('DD_VERSION', '1.0.0')

  # APM — auto-instrumentação
  c.tracing.instrument :sinatra,       analytics_enabled: true
  c.tracing.instrument :active_record, service_name: 'postgresql',
                                        comment_propagation: 'full'  # DBM
  c.tracing.instrument :rack

  # Runtime metrics
  c.runtime_metrics.enabled = true

  # Profiling contínuo
  c.profiling.enabled = true

  # Security — AppSec / RASP
  c.appsec.enabled = ENV.fetch('DD_APPSEC_ENABLED', 'false') == 'true'
end

require 'sinatra'
require 'sinatra/json'
require 'active_record'
require 'logger'
require 'json'

# ─── Logging estruturado ──────────────────────────────────────────────────────
log = Logger.new($stdout)
log.formatter = proc do |severity, datetime, _progname, msg|
  span = Datadog::Tracing.active_span
  trace_id = span&.trace_id.to_s || 0
  span_id  = span&.id  || 0
  service  = ENV.fetch('DD_SERVICE', 'ruby-crud')
  env_name = ENV.fetch('DD_ENV', 'local')
  {
    timestamp:  datetime.iso8601,
    level:      severity,
    message:    msg,
    dd: {
      service:  service,
      env:      env_name,
      trace_id: trace_id.to_s,
      span_id:  span_id.to_s
    }
  }.to_json + "\n"
end

# ─── Banco de Dados — ActiveRecord + PostgreSQL ───────────────────────────────
ActiveRecord::Base.establish_connection(
  ENV.fetch('DATABASE_URL', 'postgresql://user:password@localhost:5432/crud_db')
)

# Cria tabela se não existir
ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.table_exists?(:products)
    create_table :products do |t|
      t.string  :name,     null: false
      t.string  :category, default: 'general'
      t.float   :price,    null: false
      t.integer :stock,    default: 0
      t.timestamps
    end
  end
end

# ─── Model ────────────────────────────────────────────────────────────────────
class Product < ActiveRecord::Base
  validates :name,  presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
end

# ─── Sinatra App ──────────────────────────────────────────────────────────────
set :port,   ENV.fetch('PORT', 4567).to_i
set :bind,   '0.0.0.0'
set :logging, false  # usamos logger customizado

before { content_type :json }

# ─── Health Check ─────────────────────────────────────────────────────────────
get '/health' do
  json status: 'ok', service: 'ruby-crud', version: '1.0.0'
end

# ─── GET /products ────────────────────────────────────────────────────────────
get '/products' do
  Datadog::Tracing.trace('products.list', resource: 'GET /products') do |span|
    skip  = (params[:skip]  || 0).to_i
    limit = (params[:limit] || 100).to_i

    products = Product.offset(skip).limit(limit).all
    span.set_tag('results.count', products.length)
    log.info("Listed #{products.length} products")
    json products.map(&:as_json)
  end
end

# ─── GET /products/:id ────────────────────────────────────────────────────────
get '/products/:id' do
  Datadog::Tracing.trace('products.get') do |span|
    span.set_tag('product.id', params[:id])
    product = Product.find_by(id: params[:id])
    halt 404, json(error: 'Product not found') unless product
    json product.as_json
  end
end

# ─── POST /products ───────────────────────────────────────────────────────────
post '/products' do
  Datadog::Tracing.trace('products.create', resource: 'POST /products') do |span|
    body_data = JSON.parse(request.body.read)
    product = Product.new(
      name:     body_data['name'],
      category: body_data['category'] || 'general',
      price:    body_data['price'],
      stock:    body_data['stock'] || 0
    )

    unless product.save
      halt 422, json(errors: product.errors.full_messages)
    end

    span.set_tag('product.id',   product.id)
    span.set_tag('product.name', product.name)
    log.info("Created product id=#{product.id} name=#{product.name}")
    status 201
    json product.as_json
  end
end

# ─── PUT /products/:id ────────────────────────────────────────────────────────
put '/products/:id' do
  Datadog::Tracing.trace('products.update') do |span|
    span.set_tag('product.id', params[:id])
    product = Product.find_by(id: params[:id])
    halt 404, json(error: 'Product not found') unless product

    body_data = JSON.parse(request.body.read)
    unless product.update(body_data.slice('name', 'category', 'price', 'stock'))
      halt 422, json(errors: product.errors.full_messages)
    end

    log.info("Updated product id=#{params[:id]}")
    json product.as_json
  end
end

# ─── DELETE /products/:id ─────────────────────────────────────────────────────
delete '/products/:id' do
  Datadog::Tracing.trace('products.delete') do |span|
    span.set_tag('product.id', params[:id])
    product = Product.find_by(id: params[:id])
    halt 404, json(error: 'Product not found') unless product

    product.destroy
    log.info("Deleted product id=#{params[:id]}")
    json message: "Product #{params[:id]} deleted"
  end
end

error ActiveRecord::RecordNotFound do
  halt 404, json(error: 'Record not found')
end

error do
  span = Datadog::Tracing.active_span
  span&.set_tag('error', true)
  span&.set_tag('error.message', env['sinatra.error'].message)
  halt 500, json(error: env['sinatra.error'].message)
end
