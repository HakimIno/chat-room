defmodule ExamplePhoenix.Emojis do
  @emojis [
    {"smile", "😊"},
    {"heart", "❤️"},
    {"laugh", "😂"},
    {"wink", "😉"},
    {"cool", "😎"},
    {"sad", "😢"},
    {"angry", "😠"},
    {"love", "🥰"},
    {"thumbsup", "👍"},
    {"clap", "👏"},
    {"fire", "🔥"},
    {"party", "🎉"}
  ]

  def list_emojis do
    @emojis
  end

  def get_emoji(name) do
    case List.keyfind(@emojis, name, 0) do
      {_, emoji} -> emoji
      nil -> "😊" # default emoji
    end
  end
end
