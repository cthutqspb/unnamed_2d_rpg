components {
  id: "lootable_item"
  component: "/main/game_objects/world_item/world_item.script"
}
embedded_components {
  id: "sprite"
  type: "sprite"
  data: "default_animation: \"crystal_sword\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/assets/items/items_project_utumno.tilesource\"\n"
  "}\n"
  ""
  position {
    z: 1.0
  }
}
embedded_components {
  id: "collisionobject"
  type: "collisionobject"
  data: "type: COLLISION_OBJECT_TYPE_KINEMATIC\n"
  "mass: 0.0\n"
  "friction: 0.1\n"
  "restitution: 0.5\n"
  "group: \"interactable\"\n"
  "mask: \"cursor\"\n"
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
  "  data: 8.0\n"
  "  data: 8.0\n"
  "  data: 10.0\n"
  "}\n"
  ""
}
embedded_components {
  id: "item_name"
  type: "label"
  data: "size {\n"
  "  x: 96.0\n"
  "  y: 24.0\n"
  "}\n"
  "font: \"/assets/fonts/gui_title.font\"\n"
  "material: \"/builtins/fonts/label-df.material\"\n"
  ""
  position {
    y: 24.0
    z: 1.0
  }
}
embedded_components {
  id: "amount"
  type: "label"
  data: "size {\n"
  "  x: 12.0\n"
  "  y: 12.0\n"
  "}\n"
  "font: \"/assets/fonts/gui_title.font\"\n"
  "material: \"/builtins/fonts/label-df.material\"\n"
  ""
  position {
    x: 12.0
    y: -12.0
    z: 1.0
  }
}
