import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import jpeg from 'jpeg-js';
import { PNG } from 'pngjs';

const root = fileURLToPath(new URL('../../', import.meta.url));
const target = path.join(root, 'build', 'roblox', 'MeshData');
const source = path.join(root, 'assets');
const chunkLength = 24000;
const coordinateScale = 256;
const wheelNames = {
  'wheel-front-left': 'FrontLeft',
  'wheel-front-right': 'FrontRight',
  'wheel-back-left': 'BackLeft',
  'wheel-back-right': 'BackRight',
};

function readGlb(name) {
  const filename = path.join(source, `${name}.glb`);
  const file = fs.readFileSync(filename);
  if (file.toString('ascii', 0, 4) !== 'glTF' || file.readUInt32LE(4) !== 2) {
    throw new Error(`Expected a glTF 2 binary for ${name}`);
  }
  const jsonEnd = 20 + file.readUInt32LE(12);
  return { spec: JSON.parse(file.toString('utf8', 20, jsonEnd)), data: file.subarray(jsonEnd + 8), directory: path.dirname(filename) };
}

const readers = {
  5121: [1, 'readUInt8'],
  5123: [2, 'readUInt16LE'],
  5125: [4, 'readUInt32LE'],
  5126: [4, 'readFloatLE'],
};

function readAccessor(glb, id, width) {
  const accessor = glb.spec.accessors[id];
  const view = glb.spec.bufferViews[accessor.bufferView];
  const [bytes, read] = readers[accessor.componentType];
  const stride = view.byteStride ?? width * bytes;
  const offset = (view.byteOffset ?? 0) + (accessor.byteOffset ?? 0);
  return Array.from({ length: accessor.count }, (_, i) =>
    Array.from({ length: width }, (_, axis) => glb.data[read](offset + stride * i + axis * bytes)));
}

function transform(point, node) {
  if (node.matrix) {
    const m = node.matrix;
    return [0, 1, 2].map(i => m[i] * point[0] + m[i + 4] * point[1] + m[i + 8] * point[2] + m[i + 12]);
  }
  const scale = node.scale ?? [1, 1, 1];
  const [x, y, z] = point.map((coordinate, i) => coordinate * scale[i]);
  const [qx, qy, qz, qw] = node.rotation ?? [0, 0, 0, 1];
  const [tx, ty, tz] = node.translation ?? [0, 0, 0];
  const ax = 2 * (qy * z - qz * y);
  const ay = 2 * (qz * x - qx * z);
  const az = 2 * (qx * y - qy * x);
  return [x + qw * ax + qy * az - qz * ay + tx,
    y + qw * ay + qz * ax - qx * az + ty,
    z + qw * az + qx * ay - qy * ax + tz];
}

function sampleColor(glb, material, uv, images) {
  const pbr = glb.spec.materials[material]?.pbrMetallicRoughness ?? {};
  const factor = pbr.baseColorFactor ?? [1, 1, 1];
  const texture = pbr.baseColorTexture;
  if (!texture || !uv) return factor.slice(0, 3).map(value => Math.round(255 * value ** (1 / 2.2)));

  const imageId = glb.spec.textures[texture.index].source;
  let image = images.get(imageId);
  if (!image) {
    const spec = glb.spec.images[imageId];
    let bytes;
    if (spec.uri) {
      const file = path.resolve(glb.directory, decodeURIComponent(spec.uri));
      if (!file.startsWith(glb.directory + path.sep)) throw new Error(`Invalid texture path: ${spec.uri}`);
      bytes = fs.readFileSync(file);
    } else {
      const view = glb.spec.bufferViews[spec.bufferView];
      const offset = view.byteOffset ?? 0;
      bytes = glb.data.subarray(offset, offset + view.byteLength);
    }
    image = bytes.toString('ascii', 1, 4) === 'PNG' ? PNG.sync.read(bytes) : jpeg.decode(bytes, { useTArray: true });
    images.set(imageId, image);
  }

  const mapping = texture.extensions?.KHR_texture_transform ?? {};
  const offset = mapping.offset ?? [0, 0];
  const scale = mapping.scale ?? [1, 1];
  const sin = Math.sin(mapping.rotation ?? 0);
  const cos = Math.cos(mapping.rotation ?? 0);
  const u = uv[0] * scale[0];
  const v = uv[1] * scale[1];
  const wrap = coordinate => coordinate - Math.floor(coordinate);
  const x = Math.floor(wrap(u * cos - v * sin + offset[0]) * image.width);
  const y = Math.floor(wrap(u * sin + v * cos + offset[1]) * image.height);
  const pixel = (y * image.width + x) * 4;
  return [0, 1, 2].map(i => Math.round(image.data[pixel + i] * factor[i] ** (1 / 2.2)));
}

function sourceGroups(name, groupFor, turnAround) {
  const glb = readGlb(name);
  const groups = new Map();
  const images = new Map();
  function visit(index, parents) {
    const node = glb.spec.nodes[index];
    const chain = [node, ...parents];
    if (node.mesh != null) {
      const groupName = groupFor(node.name);
      if (!groups.has(groupName)) groups.set(groupName, { vertices: [], faces: [] });
      const group = groups.get(groupName);
      for (const primitive of glb.spec.meshes[node.mesh].primitives) {
        if ((primitive.mode ?? 4) !== 4) throw new Error(`Unsupported topology in ${name}`);
        const vertices = readAccessor(glb, primitive.attributes.POSITION, 3);
        const indices = primitive.indices == null
          ? vertices.map((_, i) => i) : readAccessor(glb, primitive.indices, 1).flat();
        const texcoords = primitive.attributes.TEXCOORD_0;
        const uvs = texcoords == null ? null : readAccessor(glb, texcoords, 2);
        const start = group.vertices.length;
        for (const vertex of vertices) {
          const point = chain.reduce(transform, vertex);
          group.vertices.push(turnAround ? [-point[0], point[1], -point[2]] : point);
        }
        for (let i = 0; i < indices.length; i += 3) {
          const face = indices.slice(i, i + 3);
          const uv = uvs && [0, 1].map(axis => face.reduce((sum, j) => sum + uvs[j][axis], 0) / 3);
          group.faces.push([...face.map(j => start + j), ...sampleColor(glb, primitive.material, uv, images)]);
        }
      }
    }
    for (const child of node.children ?? []) visit(child, chain);
  }
  for (const index of glb.spec.scenes[glb.spec.scene ?? 0].nodes) visit(index, []);
  return groups;
}

function bounds(vertices) {
  const min = [Infinity, Infinity, Infinity];
  const max = [-Infinity, -Infinity, -Infinity];
  for (const point of vertices) {
    for (let i = 0; i < 3; i++) {
      min[i] = Math.min(min[i], point[i]);
      max[i] = Math.max(max[i], point[i]);
    }
  }
  return { min, max, center: min.map((value, i) => (value + max[i]) / 2), size: min.map((value, i) => max[i] - value) };
}

function writeGroup(name, vertices, faces) {
  if (vertices.length > 60000 || faces.length > 20000) throw new Error(`${name} exceeds the EditableMesh budget`);
  const { center, size } = bounds(vertices);
  const data = Buffer.alloc(4 + 6 * vertices.length + 9 * faces.length);
  data.writeUInt16LE(vertices.length, 0);
  data.writeUInt16LE(faces.length, 2);
  let cursor = 4;
  for (const v of vertices) {
    for (let i = 0; i < 3; i++) {
      data.writeInt16LE(Math.round((v[i] - center[i]) * coordinateScale), cursor);
      cursor += 2;
    }
  }
  for (const [a, b, c, r, g, blue] of faces) {
    data.writeUInt16LE(a, cursor);
    data.writeUInt16LE(b, cursor + 2);
    data.writeUInt16LE(c, cursor + 4);
    data[cursor + 6] = r;
    data[cursor + 7] = g;
    data[cursor + 8] = blue;
    cursor += 9;
  }
  const directory = path.join(target, name);
  fs.mkdirSync(directory, { recursive: true });
  const encoded = data.toString('base64');
  const count = Math.ceil(encoded.length / chunkLength);
  for (const entry of fs.readdirSync(directory)) {
    const previous = /^Chunk(\d+)\.luau$/.exec(entry);
    if (previous && Number(previous[1]) > count) fs.unlinkSync(path.join(directory, entry));
  }
  const vector = value => `{${value.map(n => n.toFixed(5)).join(', ')}}`;
  fs.writeFileSync(path.join(directory, 'init.luau'),
    `return { center = ${vector(center)}, size = ${vector(size)}, chunks = ${count} }\n`);
  Array.from({ length: count }, (_, i) => {
    fs.writeFileSync(path.join(directory, `Chunk${i + 1}.luau`),
      `return "${encoded.slice(i * chunkLength, (i + 1) * chunkLength)}"\n`);
  });
  console.log(`${name} · ${vertices.length} sommets · ${faces.length} triangles · ${vector(center)}`);
}

function pack(name, dimensions, groupFor, turnAround = false) {
  const groups = sourceGroups(name, groupFor, turnAround);
  const assembly = bounds([...groups.values()].flatMap(group => group.vertices));
  const origin = [assembly.center[0], assembly.min[1], assembly.center[2]];
  const scale = dimensions.map((size, axis) => size / assembly.size[axis]);
  for (const [groupName, group] of groups) {
    const fit = group.vertices.map(v => v.map((coordinate, i) => (coordinate - origin[i]) * scale[i]));
    writeGroup(groupName, fit, group.faces);
  }
}

pack('garage_quartier/sedan', [6.3, 4.6, 13.8], name => wheelNames[name] ?? 'Sedan', true);
pack('garage_quartier/car-lift', [10.5, 9.15, 7.4], name => name.includes('carriage') ? 'LiftCarriage' : 'LiftBase');
for (const [name, model, size] of [
  ['garage_quartier/impact-wrench', 'Wrench', [0.85, 1.48, 1.42]],
  ['garage_quartier/reception-desk', 'Reception', [5.75, 3.55, 2.5]],
  ['garage_quartier/waiting-bench', 'Bench', [2.26, 2.66, 2.68]],
  ['garage_quartier/workbench', 'Workbench', [2.86, 3.05, 2.62]],
  ['garage_quartier/tool-cabinet', 'Cabinet', [2.73, 2.37, 2.45]],
  ['garage_quartier/parts-shelf', 'Shelf', [2.62, 3.45, 2.52]],
  ['garage_quartier/tool-trolley', 'Trolley', [2.76, 2.55, 2.45]],
  ['garage_quartier/roller-door', 'Roller', [9.35, 8.15, 0.43]],
  ['garage_quartier/oil-drum', 'Drum', [1.84, 2.36, 1.84]],
  ['garage_quartier/shop-bin', 'Bin', [1.85, 1.94, 1.85]],
  ['kenney/desk', 'Desk', [5.6, 2.62, 2.55]],
  ['kenney/chairCushion', 'Chair', [2.05, 2.68, 2.08]],
  ['kenney/bookcaseClosedDoors', 'Bookcase', [2.3, 3.4, 1.4]],
  ['kenney/pottedPlant', 'Plant', [1.52, 2.1, 1.52]],
]) {
  pack(name, size, () => model);
}
