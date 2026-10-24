"""Author beveled reusable meshes and tileable PBR source bakes in Blender.
blender --background --python tools/art/build_city_kit.py
No external texture downloads. Export geometry stays separate from Godot materials.
"""
import bpy, math, bmesh
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
GEOMETRY = ROOT/'assets/3d/city_study/parts.glb'
TEXTURES = ROOT/'assets/textures/city_study'
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
parts=[]
def finish(obj,name,bevel=0):
    obj.name=name
    if bevel:
        modifier=obj.modifiers.new('Manufactured edge bevel','BEVEL'); modifier.width=bevel; modifier.segments=3
        bpy.context.view_layer.objects.active=obj; bpy.ops.object.modifier_apply(modifier=modifier.name)
        modifier=obj.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL'); modifier.keep_sharp=True
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    for face in obj.data.polygons: face.use_smooth=True
    parts.append(obj)
bpy.ops.mesh.primitive_cube_add(size=1); finish(bpy.context.object,'box',.025)
bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=.5,depth=1); finish(bpy.context.object,'cylinder',.02)
bpy.ops.mesh.primitive_cone_add(vertices=32,radius1=.5,radius2=.08,depth=1); finish(bpy.context.object,'cone',.015)
bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,radius=.5); finish(bpy.context.object,'sphere')
bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,radius=.5)
o=bpy.context.object; mesh=bmesh.new(); mesh.from_mesh(o.data)
bmesh.ops.delete(mesh,geom=[v for v in mesh.verts if v.co.z<-.0001],context='VERTS')
for v in mesh.verts: v.co.z *= 2
mesh.to_mesh(o.data); mesh.free(); finish(o,'dome')
verts=[]; faces=[]
for i in range(33):
    u=i*math.pi/32
    for j in range(12):
        v=j*math.tau/12; radius=.44+math.cos(v)*.06
        verts.append((math.cos(u)*radius,math.sin(v)*.06,math.sin(u)*radius))
for i in range(32):
    for j in range(12):
        a=i*12+j; b=i*12+(j+1)%12; faces.append((a,b,b+12,a+12))
mesh=bpy.data.meshes.new('Quiet organic arch'); mesh.from_pydata(verts,[],faces); mesh.update()
o=bpy.data.objects.new('arch',mesh); bpy.context.collection.objects.link(o); finish(o,'arch')
bpy.ops.object.select_all(action='DESELECT')
for o in parts: o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(GEOMETRY),export_format='GLB',use_selection=True,export_materials='NONE',export_yup=True)
for o in parts: bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.mesh.primitive_plane_add(size=2)
plane=bpy.context.object
scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=8
scene.render.bake.use_pass_direct=False; scene.render.bake.use_pass_indirect=False; scene.render.bake.use_pass_color=True
scene.render.bake.margin=2
scene.view_settings.view_transform='Standard'
for name,lo,hi,roughness in [('concrete',(0.25,.29,.25),(.49,.52,.46),.84),('metal',(.23,.28,.31),(.47,.53,.56),.42),('rock',(.22,.23,.18),(.46,.45,.37),.94)]:
    mat=bpy.data.materials.new(name); mat.use_nodes=True
    plane.data.materials.clear(); plane.data.materials.append(mat)
    nodes=mat.node_tree.nodes; links=mat.node_tree.links
    bsdf=nodes.get('Principled BSDF'); output=nodes.get('Material Output')
    uv=nodes.new('ShaderNodeTexCoord'); separate=nodes.new('ShaderNodeSeparateXYZ'); links.new(uv.outputs['UV'],separate.inputs[0])
    channels=[]
    for axis,op in [('X','COSINE'),('X','SINE'),('Y','COSINE'),('Y','SINE')]:
        scale=nodes.new('ShaderNodeMath'); scale.operation='MULTIPLY'; scale.inputs[1].default_value=math.tau; links.new(separate.outputs[axis],scale.inputs[0])
        trig=nodes.new('ShaderNodeMath'); trig.operation=op; links.new(scale.outputs[0],trig.inputs[0]); channels.append(trig.outputs[0])
    vector=nodes.new('ShaderNodeCombineXYZ')
    for i,channel in enumerate(channels[:3]): links.new(channel,vector.inputs[i])
    noise=nodes.new('ShaderNodeTexNoise'); noise.noise_dimensions='4D'; noise.inputs['Scale'].default_value=8; noise.inputs['Detail'].default_value=4
    links.new(vector.outputs[0],noise.inputs['Vector']); links.new(channels[3],noise.inputs['W'])
    ramp=nodes.new('ShaderNodeValToRGB'); ramp.color_ramp.elements[0].color=(*lo,1); ramp.color_ramp.elements[1].color=(*hi,1)
    links.new(noise.outputs['Fac'],ramp.inputs[0]); links.new(ramp.outputs['Color'],bsdf.inputs['Base Color'])
    bump=nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.25 if name=='rock' else .12; bump.inputs['Distance'].default_value=.045
    links.new(noise.outputs['Fac'],bump.inputs['Height']); links.new(bump.outputs['Normal'],bsdf.inputs['Normal'])
    bsdf.inputs['Roughness'].default_value=roughness
    target=nodes.new('ShaderNodeTexImage'); nodes.active=target
    for channel,kind in [('albedo','DIFFUSE'),('normal','NORMAL'),('roughness','EMIT')]:
        image=bpy.data.images.new(name+'_'+channel,width=256,height=256,alpha=False)
        image.colorspace_settings.name='sRGB' if channel=='albedo' else 'Non-Color'
        target.image=image
        if kind=='EMIT':
            emission=nodes.new('ShaderNodeEmission'); emission.inputs['Color'].default_value=(roughness,roughness,roughness,1)
            variation=nodes.new('ShaderNodeMapRange'); variation.inputs['To Min'].default_value=roughness-.08; variation.inputs['To Max'].default_value=min(1,roughness+.08)
            links.new(noise.outputs['Fac'],variation.inputs[0]); links.new(variation.outputs[0],emission.inputs['Color']); links.new(emission.outputs[0],output.inputs['Surface'])
        bpy.ops.object.bake(type=kind,normal_space='TANGENT')
        image.filepath_raw=str(TEXTURES/(name+'_'+channel+'.png')); image.file_format='PNG'; image.save()
        if kind=='EMIT': links.new(bsdf.outputs[0],output.inputs['Surface'])
        print('BAKED',name,channel,flush=True)
print('CITY KIT COMPLETE',flush=True)
