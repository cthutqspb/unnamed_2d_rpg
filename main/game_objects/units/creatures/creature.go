components {
  id: "creature"
  component: "/main/game_objects/units/creatures/creature.script"
}
embedded_components {
  id: "interaction_collider"
  type: "collisionobject"
  data: "type: COLLISION_OBJECT_TYPE_TRIGGER\n"
  "mass: 0.0\n"
  "friction: 0.1\n"
  "restitution: 0.5\n"
  "group: \"creature\"\n"
  "mask: \"mouse\"\n"
  "embedded_collision_shape {\n"
  "  shapes {\n"
  "    shape_type: TYPE_BOX\n"
  "    position {\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 0\n"
  "    count: 3\n"
  "  }\n"
  "  data: 32.0\n"
  "  data: 32.0\n"
  "  data: 10.0\n"
  "}\n"
  "event_collision: false\n"
  "event_contact: false\n"
  ""
}
embedded_components {
  id: "sprite"
  type: "sprite"
  data: "default_animation: \"sceleton\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "size {\n"
  "  x: 64.0\n"
  "  y: 64.0\n"
  "}\n"
  "size_mode: SIZE_MODE_MANUAL\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/assets/items/project_utumno.tilesource\"\n"
  "}\n"
  ""
  position {
    z: 1.0
  }
}
embedded_components {
  id: "creature_name"
  type: "label"
  data: "size {\n"
  "  x: 96.0\n"
  "  y: 24.0\n"
  "}\n"
  "text: \"\\321\\210\\320\\272\\320\\265\\320\\273\\320\\265\\321\\202\"\n"
  "font: \"/assets/fonts/font_regular_18.font\"\n"
  "material: \"/builtins/fonts/label-df.material\"\n"
  ""
  position {
    y: 44.0
    z: 1.0
  }
}
embedded_components {
  id: "collision_collider"
  type: "collisionobject"
  data: "type: COLLISION_OBJECT_TYPE_KINEMATIC\n"
  "mass: 0.0\n"
  "friction: 0.1\n"
  "restitution: 0.5\n"
  "group: \"creature\"\n"
  "mask: \"d\"\n"
  "embedded_collision_shape {\n"
  "  shapes {\n"
  "    shape_type: TYPE_SPHERE\n"
  "    position {\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 0\n"
  "    count: 1\n"
  "  }\n"
  "  data: 32.0\n"
  "}\n"
  ""
}
