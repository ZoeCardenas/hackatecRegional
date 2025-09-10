"""
OpenTelemetry (opcional):
- Si TELEMETRY_ENABLED=true y OTEL_EXPORTER_OTLP_ENDPOINT está definido,
  se inicializa traza y métrica básicas.
- No se envían PII; usa atributos genéricos.
"""
import os

def setup_otel() -> None:
    enabled = os.getenv("TELEMETRY_ENABLED", "false").lower() == "true"
    endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "")
    if not enabled or not endpoint:
        return

    try:
        from opentelemetry import trace
        from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
        from opentelemetry.sdk.resources import Resource
        from opentelemetry.sdk.trace import TracerProvider
        from opentelemetry.sdk.trace.export import BatchSpanProcessor

        resource = Resource.create({"service.name": "salud-mental-api"})
        provider = TracerProvider(resource=resource)
        span_exporter = OTLPSpanExporter(endpoint=endpoint)
        processor = BatchSpanProcessor(span_exporter)
        provider.add_span_processor(processor)
        trace.set_tracer_provider(provider)
    except Exception:
        # No romper la app si falla OTEL
        pass
