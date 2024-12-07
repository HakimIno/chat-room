defmodule ExamplePhoenix.Accounts.RateLimit do
  import Ecto.Query
  alias ExamplePhoenix.Repo
  alias ExamplePhoenix.Accounts.Block

  @max_messages_per_minute 10  # จำนวนข้อความสูงสุดต่อนาที
  @min_interval 1  # ระยะห่างขั้นต่ำระหว่างข้อความ (วินาที)
  @initial_block_duration 120  # ระยะเวลาแบนเริ่มต้น (2 นาที)

  def check_rate_limit(ip_address) do
    # ไม่เช็ค rate limit สำหรับ localhost
    case ip_address do
      "localhost" -> {:ok, true}
      "127.0.0.1" -> {:ok, true}
      "unknown" -> {:ok, true}
      ip -> check_rate_limit_for_ip(ip)
    end
  end

  # แยกฟังก์ชันเดิมออกมา
  defp check_rate_limit_for_ip(ip_address) do
    now = NaiveDateTime.utc_now()

    case get_active_block(ip_address) do
      nil ->
        check_message_rate(ip_address, now)
      block ->
        {:error, NaiveDateTime.diff(block.expires_at, now)}
    end
  end

  defp check_message_rate(ip_address, now) do
    one_minute_ago = NaiveDateTime.add(now, -60)

    recent_messages = from(m in ExamplePhoenix.Chat.Message,
      where: m.user_ip == ^ip_address and
             m.inserted_at > ^one_minute_ago,
      order_by: [desc: :inserted_at],
      select: m.inserted_at
    ) |> Repo.all()

    cond do
      length(recent_messages) >= @max_messages_per_minute ->
        block_duration = @initial_block_duration
        create_block(ip_address, block_duration)
        {:error, block_duration}

      length(recent_messages) > 0 and
      NaiveDateTime.diff(now, hd(recent_messages)) < @min_interval ->
        block_duration = @initial_block_duration
        create_block(ip_address, block_duration)
        {:error, block_duration}

      true ->
        {:ok, true}
    end
  end

  defp get_active_block(ip_address) do
    now = NaiveDateTime.utc_now()

    from(b in Block,
      where: b.ip_address == ^ip_address and
             b.expires_at > ^now,
      order_by: [desc: :expires_at],
      limit: 1
    ) |> Repo.one()
  end

  def create_block(ip_address, duration) do
    now = NaiveDateTime.utc_now()
    expires_at = NaiveDateTime.add(now, duration)

    # ตรวจสอบการแบนก่อนหน้า
    case get_previous_block(ip_address) do
      nil ->
        # แบนครั้งแรก
        %Block{}
        |> Block.changeset(%{
          ip_address: ip_address,
          expires_at: expires_at
        })
        |> Repo.insert()

      previous_block ->
        # เพิ่มระยะเวลาแบนเป็น 2 เท่า
        new_duration = duration * 2
        new_expires_at = NaiveDateTime.add(now, new_duration)

        previous_block
        |> Block.changeset(%{expires_at: new_expires_at})
        |> Repo.update()

        {:ok, new_duration}
    end
  end

  defp get_previous_block(ip_address) do
    from(b in Block,
      where: b.ip_address == ^ip_address,
      order_by: [desc: :inserted_at],
      limit: 1
    ) |> Repo.one()
  end
end
