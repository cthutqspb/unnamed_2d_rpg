components {
  id: "frostbolt_trail"
  component: "/assets/particles/frostbolt_trail.particlefx"
}
components {
  id: "projectile"
  component: "/main/game_objects/projectiles/projectile.script"
}
embedded_components {
  id: "sprite"
  type: "sprite"
  data: "default_animation: \"frostbolt_particle\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/assets/items/project_utumno.tilesource\"\n"
  "}\n"
  ""
}
