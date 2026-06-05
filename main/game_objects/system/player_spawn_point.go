components {
  id: "player_spawn_point"
  component: "/main/game_objects/system/player_spawn_point.script"
}
embedded_components {
  id: "sprite"
  type: "sprite"
  data: "default_animation: \"player_spawn_point\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "size {\n"
  "  x: 32.0\n"
  "  y: 32.0\n"
  "}\n"
  "size_mode: SIZE_MODE_MANUAL\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/assets/items/project_utumno.tilesource\"\n"
  "}\n"
  ""
}
