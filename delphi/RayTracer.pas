unit RayTracer;

interface

uses Classes, Vcl.Graphics, Math, Generics.Collections, Windows, SysUtils;

type
  Surface = class;

  Vector = record
    x, y, z: Double;
    class operator Add(const a, b: Vector): Vector;
    class operator Subtract(const a, b: Vector): Vector;
    class operator Multiply(k: Double; const b: Vector): Vector;

    constructor Create(x, y, z: Double);

    function Dot(const v: Vector): Double;
    function Norm(): Vector;
    function Cross(const v: Vector): Vector;
    function Length(): Double;
  end;

  RGBColor = record
    b, g, r, a: Byte
  end;

  Color = record
    r, g, b: Double;

    class var White: Color;
    class var Grey: Color;
    class var Black: Color;
    class var Background: Color;
    class var DefaultColor: Color;

    constructor Create(r, g, b: Double);

    class operator Add(const a, b: Color): Color;
    class operator Multiply(k: Double; const b: Color): Color;
    class operator Multiply(const a, b: Color): Color;
    class function Clamp(v: Double): Byte; static;

    function ToDrawingColor: RGBColor;
  end;

  Camera = record
    ForwardDir: Vector;
    Right: Vector;
    Up: Vector;
    Pos: Vector;
    constructor Create(pos: Vector; lookAt: Vector);
  end;

  Thing = class;

  Ray = record
    Start: Vector;
    Dir: Vector;
    constructor Create(const start, dir: Vector);
  end;

  Intersection = record
    Thing: Thing;
    Ray: Ray;
    Dist: Double;
    constructor Create(Thing: Thing; const Ray: Ray; dist: Double);
    class function Invalid: Intersection; static;
    function IsValid: boolean;
  end;

  Thing = class(TObject)
  public
    function Intersect(const Ray: Ray): Intersection; virtual; abstract;
    function Normal(const pos: Vector): Vector; virtual; abstract;
    function Surface: Surface; virtual; abstract;
  end;

  Surface = class abstract
  public
    function Diffuse(const pos: Vector): Color; virtual; abstract;
    function Specular(const pos: Vector): Color; virtual; abstract;
    function Reflect(const pos: Vector): Double; virtual; abstract;
    function Roughness: Double; virtual; abstract;
  end;

  ShinySurface = class(Surface)
  public
    function Diffuse(const pos: Vector): Color; override;
    function Specular(const pos: Vector): Color; override;
    function Reflect(const pos: Vector): Double; override;
    function Roughness: Double; override;
  end;

  CheckerboardSurface = class(Surface)
  public
    function Diffuse(const pos: Vector): Color; override;
    function Specular(const pos: Vector): Color; override;
    function Reflect(const pos: Vector): Double; override;
    function Roughness: Double; override;
  end;

  Light = record
    Pos: Vector;
    Color: Color;
    constructor Create(pos: Vector; Color: Color);
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
    MaxDepth: Integer;
    Scene: Scene;
  public
    constructor Create;
    function Intersections(const Ray: Ray): Intersection;
    function TraceRay(const Ray: Ray; depth: Integer): Color;
    function Shade(isect: Intersection; depth: Integer): Color;
    function GetReflectionColor(Thing: Thing; const pos, normal, rd: Vector;
      depth: Integer): Color;
    function GetNaturalColor(Thing: Thing; const pos, norm, rd: Vector): Color;
    procedure Render(Scene: Scene; img: Vcl.Graphics.TBitmap);
  end;

  Sphere = class(Thing)
  private
    radius2: Double;
    center: Vector;
    _surface: Surface;
  public
    function Intersect(const Ray: Ray): Intersection; override;
    function Normal(const pos: Vector): Vector; override;
    function Surface: Surface; override;
    constructor Create(center: Vector; radius: Double; Surface: Surface);
  end;

  Plane = class(Thing)
  private
    norm: Vector;
    offset: Double;
    _surface: Surface;
  public
    function Intersect(const Ray: Ray): Intersection; override;
    function Normal(const pos: Vector): Vector; override;
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

function Vector.Cross(const v: Vector): Vector;
begin
  Result.x := y * v.z - z * v.y;
  Result.y := z * v.x - x * v.z;
  Result.z := x * v.y - y * v.x;
end;

function Vector.Dot(const v: Vector): Double;
begin
  Result := (x * v.x) + (y * v.y) + (z * v.z);
end;

function Vector.Length: Double;
begin
  Result := Sqrt(x * x + y * y + z * z);
end;

class operator Vector.Multiply(k: Double; const b: Vector): Vector;
begin
  Result.x := k * b.x;
  Result.y := k * b.y;
  Result.z := k * b.z;
end;

function Vector.Norm: Vector;
var
  divBy, m: Double;
begin
  m := self.Length();

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

  self.Pos := pos;
  self.ForwardDir := (lookAt - self.Pos).Norm;
  self.Right := 1.5 * self.ForwardDir.Cross(down).Norm();
  self.Up := 1.5 * self.ForwardDir.Cross(self.Right).Norm();
end;

{ Ray }

constructor Ray.Create(const start, dir: Vector);
begin
  self.Start := start;
  self.Dir := dir;
end;

{ Intersection }

constructor Intersection.Create(Thing: Thing; const Ray: Ray; dist: Double);
begin
  self.Thing := Thing;
  self.Ray := Ray;
  self.Dist := dist;
end;

class function Intersection.Invalid: Intersection;
begin
  Result.Thing := nil;
  Result.Dist := 0;
end;

function Intersection.IsValid: boolean;
begin
  Result := Assigned(self.Thing);
end;

{ Light }
constructor Light.Create(pos: Vector; Color: Color);
begin
  self.Pos := pos;
  self.Color := Color;
end;

{ Sphere }
constructor Sphere.Create(center: Vector; radius: Double; Surface: Surface);
begin
  self.radius2 := radius * radius;
  self.center := center;
  self._surface := Surface;
end;

function Sphere.Intersect(const Ray: Ray): Intersection;
var
  eo: Vector;
  v, dist, disc: Double;
begin

  eo := self.center - Ray.Start;
  v := eo.Dot(Ray.Dir);
  dist := 0;

  if (v >= 0) then
  begin
    disc := self.radius2 - (eo.Dot(eo) - (v * v));
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

function Sphere.Normal(const pos: Vector): Vector;
begin
  Result := (pos - self.center).Norm;
end;

function Sphere.Surface: Surface;
begin
  Result := self._surface;
end;

{ ShinySurface }
function ShinySurface.Diffuse(const pos: Vector): Color;
begin
  Result := Color.White;
end;

function ShinySurface.Reflect(const pos: Vector): Double;
begin
  Result := 0.7;
end;

function ShinySurface.Roughness: Double;
begin
  Result := 250;
end;

function ShinySurface.Specular(const pos: Vector): Color;
begin
  Result := Color.Grey;
end;

{ CheckerboardSurface }
function CheckerboardSurface.Diffuse(const pos: Vector): Color;
begin
  if ((Floor(pos.z) + Floor(pos.x)) mod 2) <> 0 then
    Result := Color.White
  else
    Result := Color.Black;
end;

function CheckerboardSurface.Reflect(const pos: Vector): Double;
begin
  if ((Floor(pos.z) + Floor(pos.x)) mod 2) <> 0 then
    Result := 0.1
  else
    Result := 0.7;
end;

function CheckerboardSurface.Roughness: Double;
begin
  Result := 150.0;
end;

function CheckerboardSurface.Specular(const pos: Vector): Color;
begin
  Result := Color.White;
end;

{ Plane }

constructor Plane.Create(norm: Vector; offset: Double; Surface: Surface);
begin
  self.norm := norm;
  self.offset := offset;
  self._surface := Surface;
end;

function Plane.Intersect(const Ray: Ray): Intersection;
var
  dist, denom: Double;
begin
  denom := self.norm.Dot(Ray.Dir);
  if (denom > 0) then
  begin
    Result := Intersection.Invalid();
  end else
  begin
    dist := (norm.Dot(Ray.Start) + offset) / (-denom);
    Result := Intersection.Create(self, Ray, dist);
  end;
end;

function Plane.Normal(const pos: Vector): Vector;
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
  self.MaxDepth := 5;
end;

function RayTracerEngine.GetNaturalColor(Thing: Thing;
  const pos, norm, rd: Vector): Color;
var
  diffuseColor, specularColor: Color;
  ldis, livec: Vector;
  testRay: Ray;
  neatIsect: Intersection;
  inShadow: boolean;
  illum, specular: Double;
  lcolor, scolor: Color;
  item: Light;
  roughness: Double;
begin

  Result := Color.DefaultColor;
  diffuseColor := Thing.Surface.Diffuse(pos);
  specularColor := Thing.Surface.Specular(pos);
  roughness := Thing.Surface.Roughness;
  testRay.Start := pos;

  for item in Scene.lights do
  begin
    ldis := item.Pos - pos;
    livec := ldis.Norm;

    testRay.Dir := livec;
    neatIsect := self.Intersections(testRay);

    inShadow := neatIsect.IsValid() and (neatIsect.Dist <= ldis.Length());

    if not inShadow then
    begin
      illum := livec.Dot(norm);
      specular := livec.Dot(rd.Norm);

      if illum > 0 then
        lcolor := illum * item.Color
      else
        lcolor := Color.DefaultColor;

      if specular > 0 then
        scolor := Math.Power(specular, roughness) * item.Color
      else
        scolor := Color.DefaultColor;

      Result := Result + ((diffuseColor * lcolor) + (specularColor * scolor));
    end;
  end;

end;

function RayTracerEngine.GetReflectionColor(Thing: Thing;
  const pos, normal, rd: Vector; depth: Integer): Color;
var
  r: Ray;
begin
  r := Ray.Create(pos, rd);
  Result := Thing.Surface.Reflect(pos) * self.TraceRay(r, depth + 1);
end;

function RayTracerEngine.Intersections(const Ray: Ray): Intersection;
var
  closest: Double;
  inter, closestInter: Intersection;
  i: Integer;
begin
  closest := MaxInt;
  closestInter := Intersection.Invalid();

  for i := 0 to High(Scene.things) do
  begin
    inter := Scene.things[i].Intersect(Ray);
    if (inter.IsValid()) and (inter.Dist < closest) then
    begin
      closestInter := inter;
      closest := inter.Dist;
    end;
  end;
  Result := closestInter;
end;

procedure RayTracerEngine.Render(Scene: Scene; img: Vcl.Graphics.TBitmap);
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
    Result := (Camera.ForwardDir + ((recenterX * Camera.Right) +
      (recenterY * Camera.Up))).Norm();
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
      testRay.Start := Scene.xcamera.Pos;
      testRay.Dir := getPoint(x, y, Scene.xcamera);

      destColor := self.TraceRay(testRay, 0);

      c := destColor.ToDrawingColor;
      start[pos] := c.b;
      start[pos + 1] := c.g;
      start[pos + 2] := c.r;
      start[pos + 3] := 255;
      pos := pos + 4;
    end;
  end;
end;

function RayTracerEngine.Shade(isect: Intersection; depth: Integer): Color;
var
  d: Vector;
  pos, normal, reflectDir: Vector;
  naturalColor, reflectedColor: Color;

begin
  d := isect.Ray.Dir;
  pos := (isect.Dist * d) + isect.Ray.Start;
  normal := isect.Thing.Normal(pos);
  reflectDir := d - (2.0 * normal.Dot(d) * normal);

  naturalColor := Color.Background + self.GetNaturalColor(isect.Thing, pos,
    normal, reflectDir);

  if depth >= self.MaxDepth then
    reflectedColor := Color.Grey
  else
    reflectedColor := self.GetReflectionColor(isect.Thing, pos, normal,
      reflectDir, depth);

  Result := naturalColor + reflectedColor;
end;

function RayTracerEngine.TraceRay(const Ray: Ray; depth: Integer): Color;
var
  isect: Intersection;
begin
  isect := self.Intersections(Ray);
  if (isect.IsValid()) then
  begin
    Result := self.Shade(isect, depth);
  end else
  begin
    Result := Color.Background;
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

  things[0] := (Plane.Create(Vector.Create(0.0, 1.0, 0.0), 0.0,    checkerboard));
  things[1] := (Sphere.Create(Vector.Create(0.0, 1.0, -0.25), 1.0, shiny));
  things[2] := (Sphere.Create(Vector.Create(-1.0, 0.5, 1.5), 0.5,  shiny));

  lights[0] := (Light.Create(Vector.Create(-2.0, 2.5, 0.0), Color.Create(0.49, 0.07, 0.07)));
  lights[1] := (Light.Create(Vector.Create(1.5, 2.5, 1.5),  Color.Create(0.07,  0.07, 0.49)));
  lights[2] := (Light.Create(Vector.Create(1.5, 2.5, -1.5), Color.Create(0.07, 0.49, 0.071)));
  lights[3] := (Light.Create(Vector.Create(0.0, 3.5, 0.0),  Color.Create(0.21,  0.21, 0.35)));

  self.xcamera := Camera.Create(Vector.Create(3.0, 2.0, 4.0), Vector.Create(-1.0, 0.5, 0.0));
end;

initialization

Color.White := Color.Create(1, 1, 1);
Color.Grey := Color.Create(0.5, 0.5, 0.5);
Color.Black := Color.Create(0, 0, 0);

Color.DefaultColor := Color.Black;
Color.Background := Color.Black;

end.
