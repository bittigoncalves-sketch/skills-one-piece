"""Reproduce source gallery; this is a Blender preview, not Godot integration proof.
blender -b -t 4 --python tools/blender/render_bara_gallery.py
"""
import bpy
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art_src/bara_bara/bara_bara_assets.blend'))
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=24;s.cycles.use_denoising=True
s.render.resolution_x=1200;s.render.resolution_y=620;s.render.resolution_percentage=100
s.world.color=(.17,.17,.17)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.375));o=bpy.context.object
m=bpy.data.materials.new('Gallery');m.diffuse_color=(.035,.045,.065,1);o.data.materials.append(m)
for name,loc,power,size in [('Key',(0,4,5),900,5),('Rim',(-3,-2,3),1100,4),('Fill',(4,1,2),400,3)]:
    bpy.ops.object.light_add(type='AREA',location=loc);l=bpy.context.object;l.name=name;l.data.energy=power;l.data.shape='DISK';l.data.size=size;l.rotation_euler=(Vector((0,0,.25))-l.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(2.1,6.7,2.8));c=bpy.context.object;c.rotation_euler=(Vector((-.10,0,.22))-c.location).to_track_quat('-Z','Y').to_euler();c.data.type='ORTHO';c.data.ortho_scale=4.65;s.camera=c
s.render.image_settings.file_format='PNG';s.render.filepath=str(ROOT/'art_src/bara_bara/source_gallery.png')
bpy.ops.render.render(write_still=True)
