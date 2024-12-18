defmodule ExamplePhoenix.Monitoring do
  require Logger

  def report_metric(name, value) do
    Logger.info("Metric: #{name} = #{value}")

    # ในอนาคตสามารถส่งไปยังระบบ monitoring เช่น StatsD, Prometheus ได้
    :ok
  end
end
