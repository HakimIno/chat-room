defmodule ExamplePhoenix.Telemetry do
  def handle_event([:chat, :url_metadata, :fetch], measurements, metadata, _config) do
    # Log metrics to your monitoring system
    Logger.info("URL metadata fetch took #{measurements.duration}ms", metadata)

    # Report to monitoring service
    ExamplePhoenix.Monitoring.report_metric("url_metadata_fetch_duration", measurements.duration)
  end
end
