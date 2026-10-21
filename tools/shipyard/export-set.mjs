// Generates the Starlane Rogue ship set as GLB + a JSON sidecar per ship.
import fs from 'node:fs';
import * as THREE from 'three';
import { GLTFExporter } from 'three/examples/jsm/exporters/GLTFExporter.js';
import { generateShip } from '../src/ships/index.js';
import { createMaterials, applyLivery, liveryById } from '../src/livery.js';

// GLTFExporter needs FileReader in binary mode.
globalThis.FileReader = class {
  readAsArrayBuffer(blob) { blob.arrayBuffer().then((b) => { this.result = b; this.onloadend && this.onloadend(); this.onload && this.onload({ target: this }); }); }
  readAsDataURL(blob) { blob.arrayBuffer().then((b) => { this.result = 'data:application/octet-stream;base64,' + Buffer.from(b).toString('base64'); this.onloadend && this.onloadend(); }); }
};

const out = process.argv[2];
const SET = [
  ['player_kestrel', 'kestrel-4821', 'fighter', 1, 'navy'],
  ['player_warden', 'warden-1550', 'corvette', 0, 'industrial'],
  ['player_marauder', 'marauder-7031', 'racer', 1, 'corporate'],
  ['pirate_fighter', 'rust-2210', 'fighter', 0, 'salvage'],
  ['pirate_fighter2', 'scrap-0451', 'fighter', 0, 'salvage'],
  ['pirate_raider', 'jackal-9134', 'racer', 0, 'salvage'],
  ['pirate_elite', 'reaver-6616', 'fighter', 2, 'stealth'],
  ['pirate_interdictor', 'snare-3377', 'surveyor', 0, 'stealth'],
  ['jammer', 'warden-0666', 'surveyor', 1, 'stealth'],
  ['boss_dreadnought', 'kazrak-0001', 'corvette', 2, 'stealth'],
  ['freighter', 'mule-5150', 'hauler', 2, 'industrial'],
  ['miner', 'quarry-2290', 'miner', 1, 'industrial'],
];
fs.mkdirSync(out, { recursive: true });
for (const [name, seed, cls, tier, livery] of SET) {
  const r = generateShip({ seed, cls, tier });
  const mats = createMaterials();
  applyLivery(mats, liveryById(livery));
  const group = new THREE.Group();
  const box = new THREE.Box3();
  for (const [ch, g] of Object.entries(r.geometries)) {
    g.computeBoundingBox();
    box.union(g.boundingBox);
  }
  const c = box.getCenter(new THREE.Vector3());
  for (const [ch, g] of Object.entries(r.geometries)) {
    const gg = g.clone();
    gg.translate(-c.x, -c.y, -c.z);
    const m = new THREE.Mesh(gg, mats[ch]);
    m.name = ch;
    group.add(m);
  }
  const scene = new THREE.Scene();
  scene.add(group);
  const buf = await new GLTFExporter().parseAsync(scene, { binary: true });
  fs.writeFileSync(`${out}/${name}.glb`, Buffer.from(buf));
  const size = box.getSize(new THREE.Vector3());
  const engines = (r.engines || []).map((e) => ({ x: e.x - c.x, y: (e.y || 0) - c.y, z: e.z - c.z, r: e.r }));
  fs.writeFileSync(`${out}/${name}.json`, JSON.stringify({ seed, cls, tier, livery, tris: r.tris,
    size: [size.x, size.y, size.z], engines, signature: r.meta.signature }, null, 1));
  console.log(name, cls, 't' + tier, r.tris, 'tris', size.toArray().map((v) => v.toFixed(1)).join('x'));
}
