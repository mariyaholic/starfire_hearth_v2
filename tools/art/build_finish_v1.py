"""Reproducible Stage F art: Blender 4.3.2, metres, +Y up in GLB.

blender --background --threads 4 --python tools/art/build_finish_v1.py
Authors three mesh LODs, three civilian hulls, tileable PBR maps and an actual
high-to-low tangent normal/AO trim bake. No external assets or texture downloads.
Albedo is sRGB; normal, AO, roughness and masks are linear. AO stays separate.
"""
import bpy, bmesh, math, random, json, hashlib, sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
GEO=ROOT/'assets/3d/finish_v1'; TEX=ROOT/'assets/textures/finish_v1'
GEO.mkdir(parents=True,exist_ok=True); TEX.mkdir(parents=True,exist_ok=True)
SOURCE=ROOT/'tools/art/sources/finish_v1.blend'; SOURCE.parent.mkdir(parents=True,exist_ok=True)
(SOURCE.parent/'.gdignore').touch()
random.seed(64133)
scene=bpy.context.scene
scene.render.engine='CYCLES'; scene.cycles.samples=12
scene.render.bake.margin=8; scene.view_settings.view_transform='Standard'
records=[]

def clear():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)

def finish(o,name,bevel=0,segments=2):
    o.name=name
    if bevel:
        m=o.modifiers.new('Manufactured edge radius','BEVEL'); m.width=bevel; m.segments=segments
        bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=m.name)
        m=o.modifiers.new('Weighted face normals','WEIGHTED_NORMAL'); m.keep_sharp=True
        bpy.ops.object.modifier_apply(modifier=m.name)
    for f in o.data.polygons: f.use_smooth=True
    return o

def cube(name,at=(0,0,0),scale=(1,1,1),bevel=.025,segments=2):
    bpy.ops.mesh.primitive_cube_add(size=1,location=at); o=bpy.context.object
    o.scale=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,bevel,segments)

def cylinder(name,at=(0,0,0),radius=.5,depth=1,n=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=radius,depth=depth,location=at)
    return finish(bpy.context.object,name,.015,2)

def export(path,objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:
        o.select_set(True); bpy.context.view_layer.objects.active=o
        triangulate=o.modifiers.new('Export triangles','TRIANGULATE'); bpy.ops.object.modifier_apply(modifier=triangulate.name)
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
        export_materials='NONE',export_yup=True,export_tangents=True)
    triangles=0
    for o in objects: o.data.calc_loop_triangles(); triangles+=len(o.data.loop_triangles)
    records.append({'file':str(path.relative_to(ROOT)),'triangles':triangles,'mesh_count':len(objects)})

# Shared manufactured/organic parts. Each name has three exported resolutions.
clear(); parts=[]
for lod,n in enumerate([32,20,12]):
    parts.append(cube('box_lod'+str(lod),bevel=.022,segments=3-lod))
    parts.append(cylinder('cylinder_lod'+str(lod),n=n))
    bpy.ops.mesh.primitive_cone_add(vertices=n,radius1=.5,radius2=.08,depth=1)
    parts.append(finish(bpy.context.object,'cone_lod'+str(lod),.012,3-lod))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=n,ring_count=n//2,radius=.5)
    parts.append(finish(bpy.context.object,'sphere_lod'+str(lod)))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=n,ring_count=n//2,radius=.5)
    o=bpy.context.object; bm=bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.co.z<-.0001],context='VERTS')
    for v in bm.verts: v.co.z*=2
    bm.to_mesh(o.data); bm.free(); parts.append(finish(o,'dome_lod'+str(lod)))
    verts=[]; faces=[]
    for i in range(n+1):
        u=i*math.pi/n
        for j in range(8):
            v=j*math.tau/8; r=.44+math.cos(v)*.06
            verts.append((math.cos(u)*r,math.sin(v)*.06,math.sin(u)*r))
    for i in range(n):
        for j in range(8):
            a=i*8+j; b=i*8+(j+1)%8; faces.append((a,b,b+8,a+8))
    mesh=bpy.data.meshes.new('Organic rib'); mesh.from_pydata(verts,[],faces); mesh.update()
    uv=mesh.uv_layers.new(name='UVMap')
    for face in mesh.polygons:
        for loop in face.loop_indices:
            index=mesh.loops[loop].vertex_index; uv.data[loop].uv=(index//8/n,index%8/8)
    o=bpy.data.objects.new('arch_lod'+str(lod),mesh); bpy.context.collection.objects.link(o)
    parts.append(finish(o,o.name))
    # Tapered, folded leaves: silhouettes come from geometry, not opaque blobs.
    vertices=[]; polygons=[]; rng=random.Random(4041)
    for i in range([128,80,48][lod]):
        theta=rng.uniform(0,math.tau); z=rng.uniform(-.38,.40)
        r=math.sqrt(max(.02,.23-z*z))*rng.uniform(.35,1)
        center=(math.cos(theta)*r,math.sin(theta)*r,z)
        length=rng.uniform(.11,.20); width=length*.45; a=len(vertices)
        pitch=rng.uniform(-1.1,1.1)
        for x,y,h in [(0,-length,0),(-width,-length*.15,0),(0,0,.027),(width,length*.1,0),(0,length,0)]:
            ly=y*math.cos(pitch)-h*math.sin(pitch); lz=y*math.sin(pitch)+h*math.cos(pitch)
            vertices.append((center[0]+x*math.cos(theta)-ly*math.sin(theta),center[1]+x*math.sin(theta)+ly*math.cos(theta),center[2]+lz))
        polygons.extend([(a,a+1,a+2),(a,a+2,a+3),(a+1,a+4,a+2),(a+2,a+4,a+3)])
    mesh=bpy.data.meshes.new('Leaf crown'); mesh.from_pydata(vertices,[],polygons); mesh.update()
    uv=mesh.uv_layers.new(name='UVMap')
    coords=[(.5,0),(0,.4),(.5,.5),(1,.6),(.5,1)]
    for face in mesh.polygons:
        for loop in face.loop_indices: uv.data[loop].uv=coords[mesh.loops[loop].vertex_index%5]
    o=bpy.data.objects.new('foliage_lod'+str(lod),mesh); bpy.context.collection.objects.link(o); parts.append(finish(o,o.name))
export(GEO/'parts.glb',parts)

# Civilian hulls, authored with functional equipment and three LODs each.
for hull in ['survey_probe','construction_ship','colony_ship']:
    for lod,n in enumerate([24,16,10]):
        clear(); objects=[]
        def box(name,at,scale):
            o=cube(name,at,scale,.016,3-lod); objects.append(o); return o
        def tube(name,at,r,d):
            o=cylinder(name,at,r,d,n); o.rotation_euler.x=math.pi/2; objects.append(o); return o
        if hull=='survey_probe':
            box('foil_core',(0,0,0),(.28,.58,.28))
            for side in [-1,1]:
                box('metal_boom',(side*.32,0,0),(.60,.035,.035))
                box('solar_array',(side*.56,0,0),(.48,.50,.025))
                if lod<2:
                    for i in range(4): box('metal_bus',(side*.56,-.18+i*.12,.02),(.48,.012,.01))
            tube('metal_sensor',(0,.35,0),.12,.13)
            box('light_lens',(0,.43,0),(.12,.025,.12))
            box('metal_antenna',(.09,0,.26),(.015,.015,.40))
        elif hull=='construction_ship':
            box('shell_bridge',(0,.05,.08),(.42,.88,.30))
            for side in [-1,1]:
                box('foil_cargo',(side*.33,-.02,0),(.20,.72,.27))
                box('metal_work_arm',(side*.40,.55,0),(.07,.57,.07))
                box('metal_gripper',(side*.29,.81,0),(.24,.06,.08))
                tube('metal_engine',(side*.31,-.51,0),.10,.20)
                box('light_thruster',(side*.31,-.64,0),(.12,.025,.12))
                if lod<2:
                    for i in range(4):box('metal_cargo_ring',(side*.33,-.29+i*.17,.15),(.22,.025,.04))
            box('glass_bridge',(0,.37,.23),(.28,.22,.035))
        else:
            box('metal_spine',(0,0,0),(.16,1.65,.16))
            for i in range(6):
                a=i*math.tau/6; x,z=math.cos(a)*.29,math.sin(a)*.29
                tube('shell_habitat',(x,0,z),.12,1.15)
                if lod<2:
                    for y in [-.37,0,.37]:tube('metal_pressure_ring',(x,y,z),.125,.035)
            box('shell_bridge',(0,.72,0),(.35,.26,.28))
            box('glass_observation',(0,.85,.02),(.24,.025,.15))
            for side in [-1,1]:
                box('solar_array',(side*.65,-.22,0),(.47,.61,.025))
                tube('metal_engine',(side*.23,-.74,0),.13,.23)
                box('light_thruster',(side*.23,-.89,0),(.15,.025,.15))
        export(GEO/(hull+'_lod'+str(lod)+'.glb'),objects)

if '--geometry-only' in sys.argv:
    manifest=json.loads((GEO/'manifest.json').read_text()); manifest['generated']=records
    manifest['sha256']={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for folder in [GEO,TEX] for p in sorted(folder.glob('*')) if p.suffix in ['.glb','.png']}
    manifest['sha256'][str(SOURCE.relative_to(ROOT))]=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    (GEO/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n'); sys.exit(0)

# Tileable materials use a periodic 4D embedding. Coarse and micro variation
# have separate frequencies and roughness variation never changes geometry.
clear(); bpy.ops.mesh.primitive_plane_add(size=2); plane=bpy.context.object
for family,lo,hi,rough in [
    ('ceramic',(.43,.41,.35),(.78,.75,.65),.48),
    ('concrete',(.38,.39,.34),(.65,.67,.60),.84),
    ('metal',(.20,.24,.27),(.48,.52,.54),.36),
    ('rock',(.32,.29,.23),(.64,.60,.50),.90),
    ('soil',(.29,.23,.14),(.57,.46,.28),.95),
    ('leaf',(.11,.24,.055),(.43,.56,.16),.72)]:
    if '--only-material' in sys.argv and family!=sys.argv[sys.argv.index('--only-material')+1]: continue
    mat=bpy.data.materials.new(family); mat.use_nodes=True
    plane.data.materials.clear(); plane.data.materials.append(mat)
    nodes=mat.node_tree.nodes; links=mat.node_tree.links; bsdf=nodes.get('Principled BSDF'); output=nodes.get('Material Output')
    uv=nodes.new('ShaderNodeTexCoord'); sep=nodes.new('ShaderNodeSeparateXYZ'); links.new(uv.outputs['UV'],sep.inputs[0])
    channels=[]
    for axis,op in [('X','COSINE'),('X','SINE'),('Y','COSINE'),('Y','SINE')]:
        scale=nodes.new('ShaderNodeMath'); scale.operation='MULTIPLY'; scale.inputs[1].default_value=math.tau; links.new(sep.outputs[axis],scale.inputs[0])
        trig=nodes.new('ShaderNodeMath'); trig.operation=op; links.new(scale.outputs[0],trig.inputs[0]); channels.append(trig.outputs[0])
    vector=nodes.new('ShaderNodeCombineXYZ')
    for i,c in enumerate(channels[:3]): links.new(c,vector.inputs[i])
    noise=nodes.new('ShaderNodeTexNoise'); noise.noise_dimensions='4D'; noise.inputs['Scale'].default_value=7; noise.inputs['Detail'].default_value=5
    links.new(vector.outputs[0],noise.inputs['Vector']); links.new(channels[3],noise.inputs['W'])
    fine=nodes.new('ShaderNodeTexNoise'); fine.noise_dimensions='4D'; fine.inputs['Scale'].default_value=74; fine.inputs['Detail'].default_value=2
    links.new(vector.outputs[0],fine.inputs['Vector']); links.new(channels[3],fine.inputs['W'])
    ramp=nodes.new('ShaderNodeValToRGB'); ramp.color_ramp.elements[0].color=(*lo,1); ramp.color_ramp.elements[1].color=(*hi,1)
    links.new(noise.outputs['Fac'],ramp.inputs[0]); links.new(ramp.outputs['Color'],bsdf.inputs['Base Color'])
    bump=nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.30 if family in ['soil','rock'] else .16; bump.inputs['Distance'].default_value=.035
    links.new(fine.outputs['Fac'],bump.inputs['Height']); links.new(bump.outputs['Normal'],bsdf.inputs['Normal'])
    target=nodes.new('ShaderNodeTexImage'); nodes.active=target
    for channel,kind in [('albedo','DIFFUSE'),('normal','NORMAL'),('roughness','EMIT')]:
        image=bpy.data.images.new(family+'_'+channel,width=512,height=512,alpha=False)
        image.colorspace_settings.name='sRGB' if channel=='albedo' else 'Non-Color'; target.image=image
        if kind=='DIFFUSE':scene.render.bake.use_pass_direct=False; scene.render.bake.use_pass_indirect=False; scene.render.bake.use_pass_color=True
        if kind=='EMIT':
            emission=nodes.new('ShaderNodeEmission'); mapping=nodes.new('ShaderNodeMapRange'); mapping.inputs['To Min'].default_value=rough-.14; mapping.inputs['To Max'].default_value=min(1,rough+.10)
            links.new(noise.outputs['Fac'],mapping.inputs[0]); links.new(mapping.outputs[0],emission.inputs['Color']); links.new(emission.outputs[0],output.inputs['Surface'])
        bpy.ops.object.bake(type=kind,normal_space='TANGENT')
        image.filepath_raw=str(TEX/(family+'_'+channel+'.png')); image.file_format='PNG'; image.save()
        if kind=='EMIT':links.new(bsdf.outputs[0],output.inputs['Surface'])
        print('BAKED',family,channel,flush=True)

if '--only-material' in sys.argv:
    manifest=json.loads((GEO/'manifest.json').read_text()); manifest['generated']=records
    manifest['sha256']={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for folder in [GEO,TEX] for p in sorted(folder.glob('*')) if p.suffix in ['.glb','.png']}
    manifest['sha256'][str(SOURCE.relative_to(ROOT))]=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    (GEO/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n'); sys.exit(0)

# Actual high-to-low geometry bake: recessed panel gaps, bevels and fasteners.
clear(); bpy.ops.mesh.primitive_plane_add(size=2); low=bpy.context.object; low.name='Trim_low'
mat=bpy.data.materials.new('Trim bake target'); mat.use_nodes=True; low.data.materials.append(mat)
target=mat.node_tree.nodes.new('ShaderNodeTexImage'); mat.node_tree.nodes.active=target
high=[]
for x in range(4):
    for y in range(4):
        px=-.75+x*.5; py=-.75+y*.5
        high.append(cube('Panel_high',(px,py,.025),(.473,.473,.045),.013,3))
        for dx,dy in [(-.195,-.195),(.195,.195)]:
            bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=.012,location=(px+dx,py+dy,.050))
            high.append(bpy.context.object)
scene.render.bake.use_selected_to_active=True; scene.render.bake.cage_extrusion=.10; scene.render.bake.max_ray_distance=.20
for channel,kind in [('trim_normal','NORMAL'),('trim_ao','AO')]:
    image=bpy.data.images.new(channel,width=1024,height=1024,alpha=False); image.colorspace_settings.name='Non-Color'; target.image=image
    bpy.ops.object.select_all(action='DESELECT')
    for o in high: o.select_set(True)
    low.select_set(True); bpy.context.view_layer.objects.active=low
    bpy.ops.object.bake(type=kind,normal_space='TANGENT')
    image.filepath_raw=str(TEX/(channel+'.png')); image.file_format='PNG'; image.save()
    print('BAKED',channel,flush=True)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
files={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for folder in [GEO,TEX] for p in sorted(folder.glob('*')) if p.suffix in ['.glb','.png']}
files[str(SOURCE.relative_to(ROOT))]=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
manifest={'version':1,'blender':bpy.app.version_string,'units':'metres; GLB +Y up','seed':64133,'source':'tools/art/build_finish_v1.py','generated':records,'sha256':files,'maps':{'albedo':'sRGB','normal':'linear OpenGL tangent','roughness':'linear','ao':'separate linear; shader-controlled'},'lods':3,'external_assets':[]}
(GEO/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('FINISH V1 COMPLETE',flush=True)
