  const FLT_MAX: f32 = 3.40282346638528859812e+38;
  const MAX_BOUNCES: u32 = 13u;
  const PI: f32 = 3.14159265358979323846;
alias TriangleVertices = array<vec2f, 6>;
var<private> vertices: TriangleVertices = TriangleVertices(
  vec2f(-1.0,-1.0),
  vec2f(-1.0,1.0),
  vec2f(1.0, -1.0),
  vec2f(1.0, -1.0),
  vec2f(-1.0,1.0),
  vec2f(1.0,1.0),
);

const OBJ_COUNT: u32 = 4u;
alias Spheres = array<Sphere, OBJ_COUNT>;
var<private> spheres: Spheres = Spheres(
  Sphere( vec3(-1., 0., -1.), 0.5, Material(1u, vec3(0.8, 0.918, 0.922), 1.5)),
  Sphere(vec3(0., -100.5, 0.), 100., Material(1u, vec3(1.0, 0.52, 0.56), 1.0)),
  Sphere(vec3(1., 0., -1.), 0.5, Material(2u, vec3(1.,1.,1.), 1.5)),
  Sphere(vec3(3., 0., -1.), 0.5, Material(0u, vec3(0.80, 0.64, 0.87), 1.0))
);

struct Rng {
  state: u32,
};
var<private> rng: Rng;

struct Scatter{
  scattered_ray: Ray,
  intersection : Intersection,
  colors: vec3f,
}

const MATERIAL_LAMBERTIAN: u32 = 0u;
const MATERIAL_METAL: u32 = 1u;
const MATERIAL_GLASS: u32 = 2u;
struct Material{
  index: u32,
  colors: vec3f,
  refractive_index: f32,
}
//add type parameter, modify scatter to check parameter, 2 different materials
fn init_rng(pixel: vec2u) {
  // Seed the PRNG using the scalar index of the pixel and the current frame count.
  let seed = (pixel.x + pixel.y * uniforms.width) ^ jenkins_hash(uniforms.frame_count);
  rng.state = jenkins_hash(seed);
}

// A slightly modified version of the "One-at-a-Time Hash" function by Bob Jenkins.
// See https://www.burtleburtle.net/bob/hash/doobs.html
fn jenkins_hash(i: u32) -> u32 {
  var x = i;
  x += x << 10u;
  x ^= x >> 6u;
  x += x << 3u;
  x ^= x >> 11u;
  x += x << 15u;
  return x;
}

// The 32-bit "xor" function from Marsaglia G., "Xorshift RNGs", Section 3.
fn xorshift32() -> u32 {
  var x = rng.state;
  x ^= x << 13;
  x ^= x >> 17;
  x ^= x << 5;
  rng.state = x;
  return x;
}

// Returns a random float in the range [0...1]. This sets the floating point exponent to zero and
// sets the most significant 23 bits of a random 32-bit unsigned integer as the mantissa. That
// generates a number in the range [1, 1.9999999], which is then mapped to [0, 0.9999999] by
// subtraction. See Ray Tracing Gems II, Section 14.3.4.
fn rand_f32() -> f32 {
  return bitcast<f32>(0x3f800000u | (xorshift32() >> 9u)) - 1.;
}

@fragment fn path_tracer_fs(@builtin(position) pos: vec4f) -> @location(0) vec4f {

  init_rng(vec2u(pos.xy));

  let origin = uniforms.camera.origin.xyz;
  let focal_length = 1.;
  let offset = vec2(rand_f32() - 0.5, rand_f32() - 0.5);
  var uv = (pos.xy + offset) / vec2f(f32(uniforms.width - 1u), f32(uniforms.height - 1u));
  uv = (2.*uv - 1.)*vec2(f32(uniforms.width)/ f32(uniforms.height), -1.0);
  let camera_rotation = mat3x3(uniforms.camera.u, uniforms.camera.v, uniforms.camera.w);
  let direction = camera_rotation * vec3(uv, focal_length);
  var ray = Ray(origin, direction);
  var through_put = vec3(1.);

  for(var bounce = 0u; bounce < MAX_BOUNCES; bounce += 1u) {
    let hit = closest_hit(ray);
    if is_valid_intersection(hit) {
      let scatter = scatter_ray(ray, hit);
      through_put = through_put * scatter.colors;
      ray = scatter.scattered_ray;
    } else {
      let sky = sky_color(ray);
      through_put = through_put * sky;
      break;
    }
  }

  var radiance_sample: vec3f;
  radiance_sample = through_put;
  

  // Fetch the old sum of samples.
  var old_sum: vec3f;  if uniforms.frame_count > 1 {
    old_sum = textureLoad(radiance_samples_old, vec2u(pos.xy), 0).xyz;
  } else {
    old_sum = vec3(0.);
  }

  // Compute and store the new sum.
  let new_sum = radiance_sample + old_sum;
  textureStore(radiance_samples_new, vec2u(pos.xy), vec4(new_sum, 0.));

  

  // Display the average.
  return vec4(new_sum / f32(uniforms.frame_count), 1.);

}
@vertex fn path_tracer_vs(@builtin(vertex_index) vid: u32) -> @builtin(position) vec4f {
  return vec4f(vertices[vid], 0.0, 1.0);
}

struct CameraUniforms {
    origin: vec3f,
    u: vec3f,
    v: vec3f,
    w: vec3f,
}

struct Uniforms {
  camera: CameraUniforms,
  width: u32,
  height: u32,
  frame_count: u32,
  _padding: u32,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var radiance_samples_old :texture_2d<f32>;
@group(0) @binding(2) var radiance_samples_new : texture_storage_2d<rgba32float, write>;


struct Ray {
  origin: vec3f,
  direction: vec3f,
}
fn sky_color(ray: Ray) -> vec3f {
  let t = 0.5 * (normalize(ray.direction).y + 1.);
  return (1. - t) * vec3(1.) + t * vec3(0.3, 0.5, 1.);
}
struct Sphere{
  center: vec3f,
  radius: f32,
  material: Material,
}
struct Intersection {
  normal: vec3f,
  t: f32,
  material_index: u32,
  colors: vec3f,
  refractive_index: f32,
}

fn no_intersection() -> Intersection {
  return Intersection(vec3(0.), -1., 0u, vec3(0.), 1.0);
}
fn point_on_ray(ray: Ray, t: f32) -> vec3<f32> {
  return ray.origin + t * ray.direction;
}
fn intersect_sphere(ray: Ray, sphere: Sphere) -> Intersection {
  let v = ray.origin - sphere.center;
  let a = dot(ray.direction, ray.direction);
  let b = dot(v, ray.direction);
  let c = dot(v, v) - sphere.radius * sphere.radius;

  let d = b * b - a * c;
  if d < 0. {
    return no_intersection();
  }

  let sqrt_d = sqrt(d);
  let recip_a = 1. / a;
  let mb = -b;
  let t1 = (mb - sqrt_d) * recip_a;
  let t2 = (mb + sqrt_d) * recip_a;
  let t = select(t2, t1, t1 > 0.);
  if t <= 0. {
    return no_intersection();
  }

  let p = point_on_ray(ray, t);
  let N = (p - sphere.center) / sphere.radius;
  return Intersection(N, t, sphere.material.index, sphere.material.colors, sphere.material.refractive_index);
}
fn closest_hit(ray: Ray) -> Intersection {
var closest = Intersection(vec3(0),FLT_MAX, 0u, vec3(0.), 1.0);
  for (var i = 0u; i < OBJ_COUNT; i += 1u) {
    let hit = intersect_sphere(ray, spheres[i]);
    if hit.t > 0. && hit.t < closest.t {
      closest = hit;
    }
  }
  if(closest.t == FLT_MAX){
    return no_intersection();
  }
  return closest;
}
fn is_valid_intersection(hit: Intersection) -> bool {
  return hit.t > 0.;
}

fn sample_sphere() -> vec3f {
  let r0 = rand_f32();
  let r1 = rand_f32();

  let y = 1. - 2. * r0;
  let xz_r = sqrt(1. - y * y);
  let phi = 2*PI * r1;
  return vec3(xz_r * cos(phi), y, xz_r * sin(phi));
}


fn scatter_ray(ray_in: Ray, hit: Intersection) -> Scatter {
  let hit_point = point_on_ray(ray_in, hit.t);
  let epsilon = 0.001;
  var normal = hit.normal;
  if dot(ray_in.direction, normal) > 0. {
    normal = -normal;
  }

  if (hit.material_index == MATERIAL_LAMBERTIAN) {
    // let scattered_ray = Ray(hit_point + normal * epsilon, normalize(random_in_unit_sphere()));
    // let albedo = vec3(0.8, 0.3, 0.3)*2.0*abs(dot(normalize(hit.normal), normalize(scattered_ray.direction)));
    let rand_dir = sample_sphere();
    let scattered_dir = select(-rand_dir, rand_dir, dot(rand_dir, normal) > 0.);
    let scattered_ray = Ray(hit_point + normal * epsilon, scattered_dir);
    let cos_theta = max(0.0, dot(normal, scattered_dir));
    let albedo = hit.colors * cos_theta * 2.0;
    return Scatter(scattered_ray, hit, albedo);
  } else if(hit.material_index == MATERIAL_METAL){
    let reflected = reflect(normalize(ray_in.direction), normal);
    let scattered_ray = Ray(hit_point + normal * epsilon, normalize(reflected));
    let albedo = hit.colors;
    return Scatter(scattered_ray, hit, albedo);
  }else if(hit.material_index == MATERIAL_GLASS){
    let cos_theta = dot(-normalize(ray_in.direction), normalize(hit.normal)); 
    let ior = select(1.0 / hit.refractive_index, hit.refractive_index, cos_theta < 0.);
    
    let sin_incident = (1.0 - cos_theta * cos_theta) * (ior * ior);
    
    if(sin_incident > 1.0){
      let reflected = reflect(normalize(ray_in.direction), normal);
      let scattered_ray = Ray(hit_point + normal * epsilon, normalize(reflected));
      return Scatter(scattered_ray, hit, hit.colors);
    }else{
      let refracted = refract(normalize(ray_in.direction), normalize(normal), ior);
      let scattered_ray = Ray(hit_point - normal * epsilon, normalize(refracted));
      return Scatter(scattered_ray, hit, hit.colors);
    }
  }
  return Scatter(Ray(vec3(0.), vec3(0.)), hit, vec3(0.));
}