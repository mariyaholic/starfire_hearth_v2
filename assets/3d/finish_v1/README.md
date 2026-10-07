# Stage F finish source and runtime conventions

Rebuild with Blender 4.3.2 using `tools/art/build_finish_v1.py`. The script is the
deterministic source for every part, hull and tile map. The retained
`tools/art/sources/finish_v1.blend` contains the actual trim high/low bake scene;
it is excluded from runtime import. No external artwork was used.

GLBs use metres and +Y up. Shared parts have an origin at their assembly pivot:
boxes/cylinders/spheres are centred; domes and ribs sit on their base. Civilian
hulls are centred on their structural spine and run along Z. Each mesh has UV0,
normals and tangents. Role prefixes provide explicit surface assignments in
Godot. Three independent hull exports and three resolutions of shared parts are
used at runtime; the near hero assemblies inherit those part LODs.

The twenty PNG maps are six 512-square albedo/normal/roughness sets and a
1024-square high-to-low trim normal/AO pair. Albedo samplers convert sRGB;
roughness, AO and OpenGL tangent normals are linear. Godot generates mipmaps.
This review uses lossless textures after slow software-GL compressed-texture
validation stalls. Compression on target GPUs belongs to Stage G. AO is separate
and its shader strength can be set to zero. Solar-cell and material-role masks
are evaluated by the versioned shader/assembly, rather than a colour-only finish.

`manifest.json` records Blender, deterministic seed, triangle counts and file
checksums. Physical planet/region generators and baked planetary map schema stay
at version 1. GPU material catalogs are version 2; civilian kit is version 2;
city kit is version 3. Catalogs 1 and 2 retain their original rendering paths.
The explicit visual upgrade changes these catalogs while retaining geography.
