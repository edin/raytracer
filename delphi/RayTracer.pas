unit RayTracer;

interface

uses Classes, Vcl.Graphics, Math, Generics.Collections, Windows, SysUtils;

type
  Surface = class;
  Light = class;

  Vector = record
    x, y, z: Double;
    class operator Add(const a, b: Vector): Vector;
    class operator Subtract(const a, b: Vector): Vector;
    class operator Multiply(k: Double; const b: Vector): Vector;

    constructor Create(x, y, z: Double);

    function dot(const v: Vector): Double;
    function norm(): Vector;
    function cross(const v: Vector): Vector;
    function mag(): Double;
  end;

  RGBColor = record
    b, g, r, a: Byte end;

    Color = record r, g, b: Double;

    class var white: Color;
    class var grey: Color;
    class var black: Color;
    class var background: Color;
    class var defaultColor: Color;

    constructor Create(r, g, b: Double);

    class operator Add(const a, b: Color): Color;
    class operator Multiply(k: Double; const b: Color): Color;
    class operator Multiply(const a, b: Color): Color;

    class function Clamp(v: Double): Byte; static;
    function ToDrawingColor: RGBColor;
  end;

  Camera = class(TObject)
  public
    forwardDir: Vector;
    right: Vector;
    up: Vector;
    pos: Vector;
    constructor Create(pos: Vector; lookAt: Vector);
  end;

  Thing = class;

  Ray = record
    start: Vector;
    dir: Vector;
  public
    constructor Create(const start, dir: Vector);
  end;

  Intersection = record
    Thing: Thing;
    Ray: Ray;
    dist: Double;
    constructor Create(Thing: Thing; const Ray: Ray; dist: Double);
    class function Invalid: Intersection; static;

    function IsValid: boolean;
  end;

  Thing = class(TObject)
  public
    function intersect(const Ray: Ray): Intersection; virtual; abstract;
    function normal(const pos: Vector): Vector; virtual; abstract;
    function Surface: Surface; virtual; abstract;
  end;

  Surface = class abstract
  public
    function diffuse(const pos: Vector): Color; virtual; abstract;
    function specular(const pos: Vector): Color; virtual; abstract;
    function reflect(const pos: Vector): Double; virtual; abstract;
    function roughness: Double; virtual; abstract;
  end;

  ShinySurface = class(Surface)
  public
    function diffuse(const pos: Vector): Color; override;
    function specular(const pos: Vector): Color; override;
    function reflect(const pos: Vector): Double; override;
    function roughness: Double; override;
  end;

  CheckerboardSurface = class(Surface)
  public
    function diffuse(const pos: Vector): Color; override;
    function specular(const pos: Vector): Color; override;
    function reflect(const pos: Vector): Double; override;
    function roughness: Double; override;
  end;

  Scene = class(TObject)
  public
    things: array of Thing;
    lights: array of Light;
    xcamera: Camera;
    constructor Create;
  end;

  RayTracerEngine = class
  private
    maxDepth: Integer;
    Scene: Scene;

  public
    constructor Create;

    function intersections(const Ray: Ray): Intersection;
    function testRay(const Ray: Ray): Double;
    function traceRay(const Ray: Ray; depth: Integer): Color;
    function shade(isect: Intersection; depth: Integer): Color;

    function getReflectionColor(Thing: Thing; const pos, normal, rd: Vector;
      depth: Integer): Color;
    function getNaturalColor(Thing: Thing; const pos, norm, rd: Vector): Color;
    procedure render(Scene: Scene; img: Vcl.Graphics.TBitmap);
  end;

  Light = class
  public
    pos: Vector;
    Color: Color;
    constructor Create(pos: Vector; Color: Color);
  end;

  Sphere = class(Thing)
  private
    radius2: Double;
    center: Vector;
    _surface: Surface;
  public
    function intersect(const Ray: Ray): Intersection; override;
    function normal(const pos: Vector): Vector; override;
    function Surface: Surface; override;
    constructor Create(center: Vector; radius: Double; Surface: Surface);
  end;

  Plane = class(Thing)
  private
    norm: Vector;
    offset: Double;
    _surface: Surface;
  public
    function intersect(const Ray: Ray): Intersection; override;
    function normal(const pos: Vector): Vector; override;
    function Surface: Surface; override;
    constructor Create(norm: Vector; offset: Double; Surface: Surface);
  end;

implementation

{ Vector }
constructor Vector.Create(x, y, z: Double);
begin
  self.x := x;
  self.y := y;
  self.z := z;
end;

function Vector.cross(const v: Vector): Vector;
begin
  Result.x := y * v.z - z * v.y;
  Result.y := z * v.x - x * v.z;
  Result.z := x * v.y - y * v.x;
end;

function Vector.dot(const v: Vector): Double;
begin
  Result := (x * v.x) + (y * v.y) + (z * v.z);
end;

function Vector.mag: Double;
begin
  Result := Sqrt(x * x + y * y + z * z);
end;

class operator Vector.Multiply(k: Double; const b: Vector): Vector;
begin
  Result.x := k * b.x;
  Result.y := k * b.y;
  Result.z := k * b.z;
end;

function Vector.norm: Vector;
var
  divBy, m: Double;
begin
  m := self.mag();

  if (m = 0) then
    divBy := MaxDouble
  else
    divBy := 1.0 / m;

  Result := divBy * self;
end;

class operator Vector.Subtract(const a, b: Vector): Vector;
begin
  Result.x := a.x - b.x;
  Result.y := a.y - b.y;
  Result.z := a.z - b.z;
end;

class operator Vector.Add(const a, b: Vector): Vector;
begin
  Result.x := a.x + b.x;
  Result.y := a.y + b.y;
  Result.z := a.z + b.z;
end;

{ Color }

class operator Color.Add(const a, b: Color): Color;
begin
  Result.r := a.r + b.r;
  Result.g := a.g + b.g;
  Result.b := a.b + b.b;
end;

class operator Color.Multiply(k: Double; const b: Color): Color;
begin
  Result.r := k * b.r;
  Result.g := k * b.g;
  Result.b := k * b.b;
end;

class function Color.Clamp(v: Double): Byte;
begin
  if v > 255 then
    Result := 255
  else
    Result := Byte(Floor(v));
end;

constructor Color.Create(r, g, b: Double);
begin
  self.r := r;
  self.g := g;
  self.b := b;
end;

class operator Color.Multiply(const a, b: Color): Color;
begin
  Result.r := a.r * b.r;
  Result.g := a.g * b.g;
  Result.b := a.b * b.b;
end;

function Color.ToDrawingColor: RGBColor;
begin
  Result.r := Color.Clamp(self.r * 255.0);
  Result.g := Color.Clamp(self.g * 255.0);
  Result.b := Color.Clamp(self.b * 255.0);
  Result.a := 255;
end;

{ Camera }

constructor Camera.Create(pos, lookAt: Vector);
var
  down: Vector;
begin

  down := Vector.Create(0.0, -1.0, 0.0);

  self.pos := pos;
  self.forwardDir := (lookAt - self.pos).norm;
  self.right := 1.5 * self.forwardDir.cross(down).norm();
  self.up := 1.5 * self.forwardDir.cross(self.right).norm();
end;

{ Ray }

constructor Ray.Create(const start, dir: Vector);
begin
  self.start := start;
  self.dir := dir;
end;

{ Intersection }

constructor Intersection.Create(Thing: Thing; const Ray: Ray; dist: Double);
begin
  self.Thing := Thing;
  self.Ray := Ray;
  self.dist := dist;
end;

class function Intersection.Invalid: Intersection;
begin
  Result.Thing := nil;
  Result.dist := 0;
end;

function Intersection.IsValid: boolean;
begin
  Result := Assigned(self.Thing);
end;

{ Light }
constructor Light.Create(pos: Vector; Color: Color);
begin
  self.pos := pos;
  self.Color := Color;
end;

{ Sphere }
constructor Sphere.Create(center: Vector; radius: Double; Surface: Surface);
begin
  self.radius2 := radius * radius;
  self.center := center;
  self._surface := Surface;
end;

function Sphere.intersect(const Ray: Ray): Intersection;
var
  eo: Vector;
  v, dist, disc: Double;
begin

  eo := self.center - Ray.start;
  v := eo.dot(Ray.dir);
  dist := 0;

  if (v >= 0) then
  begin
    disc := self.radius2 - (eo.dot(eo) - (v * v));
    if (disc >= 0) then
    begin
      dist := v - Sqrt(disc);
    end;
  end;

  if (dist = 0) then
    Result := Intersection.Invalid()
  else
  begin
    Result := Intersection.Create(self, Ray, dist);
  end;

end;

function Sphere.normal(const pos: Vector): Vector;
begin
  Result := (pos - self.center).norm;
end;

function Sphere.Surface: Surface;
begin
  Result := self._surface;
end;

{ ShinySurface }

function ShinySurface.diffuse(const pos: Vector): Color;
begin
  Result := Color.white;
end;

function ShinySurface.reflect(const pos: Vector): Double;
begin
  Result := 0.7;
end;

function ShinySurface.roughness: Double;
begin
  Result := 250;
end;

function ShinySurface.specular(const pos: Vector): Color;
begin
  Result := Color.grey;
end;

{ CheckerboardSurface }
function CheckerboardSurface.diffuse(const pos: Vector): Color;
begin
  if ((Floor(pos.z) + Floor(pos.x)) mod 2) <> 0 then
    Result := Color.white
  else
    Result := Color.black;
end;

function CheckerboardSurface.reflect(const pos: Vector): Double;
begin
  if ((Floor(pos.z) + Floor(pos.x)) mod 2) <> 0 then
    Result := 0.1
  else
    Result := 0.7;
end;

function CheckerboardSurface.roughness: Double;
begin
  Result := 150.0;
end;

function CheckerboardSurface.specular(const pos: Vector): Color;
begin
  Result := Color.white;
end;

{ Plane }

constructor Plane.Create(norm: Vector; offset: Double; Surface: Surface);
begin
  self.norm := norm;
  self.offset := offset;
  self._surface := Surface;
end;

function Plane.intersect(const Ray: Ray): Intersection;
var
  dist, denom: Double;
begin
  denom := self.norm.dot(Ray.dir);
  if (denom > 0) then
  begin
    Result := Intersection.Invalid();
  end
  else
  begin
    dist := (norm.dot(Ray.start) + offset) / (-denom);
    Result := Intersection.Create(self, Ray, dist);
  end;

end;

function Plane.normal(const pos: Vector): Vector;
begin
  Result := self.norm;
end;

function Plane.Surface: Surface;
begin
  Result := _surface;
end;

{ RayTracerEngine }

constructor RayTracerEngine.Create;
begin
  self.maxDepth := 5;
end;

function RayTracerEngine.getNaturalColor(Thing: Thing;
  const pos, norm, rd: Vector): Color;
var
  diffuseColor, specularColor: Color;
  ldis, livec: Vector;
  testRay: Ray;
  neatIsect: Double;
  inShadow: boolean;
  illum, specular: Double;
  lcolor, scolor: Color;
  item: Light;
  roughness: Double;
begin

  Result := Color.defaultColor;
  diffuseColor := Thing.Surface.diffuse(pos);
  specularColor := Thing.Surface.specular(pos);
  roughness := Thing.Surface.roughness;
  testRay.start := pos;

  for item in Scene.lights do
  begin
    ldis := item.pos - pos;
    livec := ldis.norm;

    testRay.dir := livec;
    neatIsect := self.testRay(testRay);

    inShadow := ((not IsNan(neatIsect)) and (neatIsect <= ldis.mag));

    if not inShadow then
    begin
      illum := livec.dot(norm);

      if illum > 0 then
        lcolor := illum * item.Color
      else
        lcolor := Color.defaultColor;

      specular := livec.dot(rd.norm);

      if specular > 0 then
        scolor := Math.Power(specular, roughness) * item.Color
      else
        scolor := Color.defaultColor;

      Result := Result + ((diffuseColor * lcolor) + (specularColor * scolor));
    end;
  end;

end;

function RayTracerEngine.getReflectionColor(Thing: Thing;
  const pos, normal, rd: Vector; depth: Integer): Color;
var
  r: Ray;
begin
  r := Ray.Create(pos, rd);
  Result := Thing.Surface.reflect(pos) * self.traceRay(r, depth + 1);
end;

function RayTracerEngine.intersections(const Ray: Ray): Intersection;
var
  closest: Double;
  inter, closestInter: Intersection;
  i: Integer;
begin
  closest := MaxInt;
  closestInter := Intersection.Invalid();

  for i := 0 to High(Scene.things) do
  begin
    inter := Scene.things[i].intersect(Ray);
    if (inter.IsValid()) and (inter.dist < closest) then
    begin
      closestInter := inter;
      closest := inter.dist;
    end;
  end;
  Result := closestInter;
end;

procedure RayTracerEngine.render(Scene: Scene; img: Vcl.Graphics.TBitmap);
var
  x, y, w, h: Integer;
  destColor: Color;
  testRay: Ray;
  c: RGBColor;
  stride, pos: Integer;
  start: PBYTE;

  function getPoint(x, y: Integer; Camera: Camera): Vector;
  var
    recenterX, recenterY: Double;
  begin
    recenterX := (x - (w / 2.0)) / 2.0 / w;
    recenterY := -(y - (h / 2.0)) / 2.0 / h;
    Result := (Camera.forwardDir + ((recenterX * Camera.right) +
      (recenterY * Camera.up))).norm();
  end;

begin

  self.Scene := Scene;
  w := img.Width - 1;
  h := img.Height - 1;

  start := img.ScanLine[0];
  stride := Integer(img.ScanLine[1]) - Integer(img.ScanLine[0]);

  for y := 0 to h do
  begin
    pos := y * stride;
    for x := 0 to w do
    begin
      testRay.start := Scene.xcamera.pos;
      testRay.dir := getPoint(x, y, Scene.xcamera);

      destColor := self.traceRay(testRay, 0);

      c := destColor.ToDrawingColor;
      start[pos] := c.b;
      start[pos + 1] := c.g;
      start[pos + 2] := c.r;
      start[pos + 3] := 255;
      pos := pos + 4;
    end;
  end;
end;

function RayTracerEngine.shade(isect: Intersection; depth: Integer): Color;
var
  d: Vector;
  pos, normal, reflectDir: Vector;
  naturalColor, reflectedColor: Color;

begin
  d := isect.Ray.dir;
  pos := (isect.dist * d) + isect.Ray.start;
  normal := isect.Thing.normal(pos);
  reflectDir := d - (2.0 * normal.dot(d) * normal);

  naturalColor := Color.background + self.getNaturalColor(isect.Thing, pos,
    normal, reflectDir);

  if depth >= self.maxDepth then
    reflectedColor := Color.grey
  else
    reflectedColor := self.getReflectionColor(isect.Thing, pos, normal,
      reflectDir, depth);

  Result := naturalColor + reflectedColor;
end;

function RayTracerEngine.testRay(const Ray: Ray): Double;
var
  isect: Intersection;
begin
  isect := self.intersections(Ray);
  if isect.IsValid() then
  begin
    Result := isect.dist;
  end
  else
  begin
    Result := NaN;
  end;
end;

function RayTracerEngine.traceRay(const Ray: Ray; depth: Integer): Color;
var
  isect: Intersection;
begin
  isect := self.intersections(Ray);
  if (isect.IsValid()) then
  begin
    Result := self.shade(isect, depth);
  end
  else
  begin
    Result := Color.background;
  end;
end;

{ Scene }

constructor Scene.Create;
var
  shiny: ShinySurface;
  checkerboard: CheckerboardSurface;
begin

  SetLength(things, 3);
  SetLength(lights, 4);

  shiny := ShinySurface.Create;
  checkerboard := CheckerboardSurface.Create;

  things[0] := (Plane.Create(Vector.Create(0.0, 1.0, 0.0), 0.0, checkerboard));
  things[1] := (Sphere.Create(Vector.Create(0.0, 1.0, -0.25), 1.0, shiny));
  things[2] := (Sphere.Create(Vector.Create(-1.0, 0.5, 1.5), 0.5, shiny));

  lights[0] := (Light.Create(Vector.Create(-2.0, 2.5, 0.0), Color.Create(0.49,
    0.07, 0.07)));
  lights[1] := (Light.Create(Vector.Create(1.5, 2.5, 1.5), Color.Create(0.07,
    0.07, 0.49)));
  lights[2] := (Light.Create(Vector.Create(1.5, 2.5, -1.5), Color.Create(0.07,
    0.49, 0.071)));
  lights[3] := (Light.Create(Vector.Create(0.0, 3.5, 0.0), Color.Create(0.21,
    0.21, 0.35)));

  self.xcamera := Camera.Create(Vector.Create(3.0, 2.0, 4.0),
    Vector.Create(-1.0, 0.5, 0.0));
end;

initialization

Color.white := Color.Create(1, 1, 1);
Color.grey := Color.Create(0.5, 0.5, 0.5);
Color.black := Color.Create(0, 0, 0);

Color.defaultColor := Color.black;
Color.background := Color.black;

end.
