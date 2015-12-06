unit RayTracer;

interface

uses Classes, Graphics, Math, Generics.Collections,Windows, SysUtils;

type
Surface = class;
Light = class;

Vector = record
    x,y,z:Double ;
    class operator Add(a, b: Vector): Vector;
    class operator Subtract(a, b: Vector): Vector;
    class operator Multiply(k:Double ; b: Vector): Vector;

    constructor Create(x,y,z:Double );

    function dot(v:Vector):Double;
    function norm():Vector;
    function cross(v:Vector):Vector;
    function mag():Double ;
end;

RGBColor = record
  r,g,b:Byte
end;

Color = record
  r,g,b:Double ;

  class var  white: Color;
  class var  grey: Color;
  class var  black: Color;
  class var  background: Color;
  class var  defaultColor: Color;

  constructor Create(r,g,b:Double );

  class operator Add(a, b: Color): Color;
  class operator Multiply(k:Double ; b: Color): Color;
  class operator Multiply(a:Color; b: Color): Color;

  class function Clamp(v:Double ):Byte;static;
  function ToDrawingColor:RGBColor;
end;

Camera = class(TObject)
public
  forwardDir: Vector;
  right: Vector;
  up: Vector;
  pos: Vector;
  constructor Create(pos:Vector; lookAt:Vector);
end;

Thing = class;
Ray = class;

Intersection = class(TObject)
  thing: Thing;
  ray:  Ray;
  dist: Double ;
  constructor Create(thing:Thing; ray:Ray; dist:Double );
end;

Thing = class(TObject)
  public
  function intersect(ray: Ray) : Intersection; virtual; abstract;
  function normal (pos: Vector): Vector;virtual; abstract;
  function surface:Surface;virtual;  abstract;
end;

Ray = class(TObject)
   start:Vector;
   dir:Vector;
   public
   constructor Create();overload;
   constructor Create(start,dir:Vector);overload;
   function ToString:String;override;
end;

Surface = class abstract
public
  function diffuse(pos:Vector):Color; virtual;  abstract;
  function specular(pos:Vector):Color; virtual;  abstract;
  function reflect(pos:Vector):Double ; virtual;  abstract;
  function roughness:Double ;virtual;abstract;
end;

ShinySurface = class(Surface)
  public
    function diffuse(pos: Vector): Color; override;
    function specular(pos: Vector): Color; override;
    function reflect(pos: Vector): Double ; override;
    function roughness: Double ; override;
end;

CheckerboardSurface = class(Surface)
  public
    function diffuse(pos: Vector): Color; override;
    function specular(pos: Vector): Color; override;
    function reflect(pos: Vector): Double ; override;
    function roughness: Double ; override;
end;

Scene = class(TObject)
  public
    things:TList<Thing>;
    lights:TList<Light>;
    xcamera:Camera;
    constructor Create;
end;

RayTracerEngine = class
  private
    maxDepth:Integer;

  public
    constructor Create;

    function intersections(ray: Ray; scene: Scene):Intersection;
    function testRay(ray: Ray; scene: Scene):Double ;
    function traceRay(ray: Ray; scene: Scene; depth: integer): Color;
    function shade(isect: Intersection; scene: Scene; depth: integer):Color;

    function getReflectionColor(thing: Thing; pos: Vector; normal:
      Vector; rd: Vector; scene: Scene; depth: integer):Color;
    function getNaturalColor(thing: Thing; pos: Vector; norm: Vector; rd: Vector; scene: Scene):Color;

    procedure render(scene:Scene;img:Graphics.TBitmap);

end;


Light = class
public
  pos:Vector;
  color:Color;
  constructor Create(pos:Vector; color:Color);
end;

Sphere = class(Thing)
  private
    radius2:Double ;
    center:Vector;
    _surface:Surface;
  public
    function intersect(ray: Ray): Intersection; override;
    function normal(pos: Vector): Vector; override;
    function surface: Surface; override;

    constructor Create(center:Vector; radius:Double ; surface:Surface);
end;

Plane = class(Thing)
  private
    norm:Vector;
    offset:Double ;
    _surface:Surface;
  public
    function intersect(ray: Ray): Intersection; override;
    function normal(pos: Vector): Vector; override;
    function surface: Surface; override;

    constructor Create(norm:Vector; offset:Double ; surface:Surface);
end;


implementation

{ Vector }
constructor Vector.Create(x,y,z:Double );
begin
   self.x := x;
   self.y := y;
   self.z := z;
end;

function Vector.cross(v: Vector): Vector;
begin
    Result.x := y * v.z - z * v.y;
    Result.y := z * v.x - x * v.z;
    Result.z := x * v.y - y * v.x;
end;

function Vector.dot(v: Vector): Double ;
begin
    Result := x * v.x +
              y * v.y +
              z * v.z;
end;

function Vector.mag: Double ;
begin
    Result := Sqrt(x * x + y * y + z * z);
end;

class operator Vector.Multiply(k: Double ; b: Vector): Vector;
begin
    Result.x := k * b.x;
    Result.y := k * b.y;
    Result.z := k * b.z;
end;

function Vector.norm: Vector;
var
    divBy, m:Double ;
begin
    m := self.mag();

    if (m = 0) then
      divBy := MaxDouble
    else
      divBy := 1.0 / m;

    Result := divBy * self;
end;

class operator Vector.Subtract(a, b: Vector): Vector;
begin
    Result.x := a.x - b.x;
    Result.y := a.y - b.y;
    Result.z := a.z - b.z;

end;

class operator Vector.Add(a, b: Vector): Vector;
begin
    Result.x := a.x + b.x;
    Result.y := a.y + b.y;
    Result.z := a.z + b.z;
end;

{ Color }

class operator Color.Add(a, b: Color): Color;
begin
    Result.r := a.r + b.r;
    Result.g := a.g + b.g;
    Result.b := a.b + b.b;
end;

class operator Color.Multiply(k: Double ; b: Color): Color;
begin
  Result.r := k*b.r;
  Result.g := k*b.g;
  Result.b := k*b.b;
end;

class function Color.Clamp(v: Double ): Byte;
begin
  if v > 255 then
    Result := 255
  else
    Result := Byte(Floor(v));

end;

constructor Color.Create(r, g, b: Double );
begin
  self.r := r;
  self.g := g;
  self.b := b;
end;

class operator Color.Multiply(a, b: Color): Color;
begin
  Result.r := a.r * b.r;
  Result.g := a.g * b.g;
  Result.b := a.b * b.b;
end;

function Color.ToDrawingColor: RGBColor;
begin
  Result.r :=  Color.Clamp(self.r * 255.0);
  Result.g :=  Color.Clamp(self.g * 255.0);
  Result.b :=  Color.Clamp(self.b * 255.0);
end;

{ Camera }

constructor Camera.Create(pos, lookAt: Vector);
var
  down:Vector;
begin

  down := Vector.Create(0.0, -1.0, 0.0);

  self.pos        := pos;
  self.forwardDir := (lookAt - self.pos).norm;
  self.right      := 1.5 *  self.forwardDir.cross(down).norm();
  self.up         := 1.5 *  self.forwardDir.cross(self.right).norm() ;
end;

{ Ray }

constructor Ray.Create(start, dir: Vector);
begin
  self.start := start;
  self.dir   := dir;
end;

constructor Ray.Create;
begin
end;

function Ray.ToString: String;
begin
  Result := Format ('[%.4f,%.4f,%.4f]', [dir.x, dir.y, dir.z]);
end;

{ Intersection }

constructor Intersection.Create(thing: Thing; ray: Ray; dist: Double );
begin
  self.thing := thing;
  self.ray := ray;
  self.dist := dist;
end;


{ Light }
constructor Light.Create(pos: Vector; color: Color);
begin
  self.pos := pos;
  self.color := color;
end;

{ Sphere }
constructor Sphere.Create(center: Vector; radius: Double ; surface: Surface);
begin
  self.radius2 := radius * radius;
  self.center := center;
  self._surface := surface;
end;

function Sphere.intersect(ray: Ray): Intersection;
var
  eo:Vector;
  v,dist,disc:Double ;
begin

  eo    := self.center - ray.start;
  v     := eo.dot(ray.dir);
  dist  := 0;

  if (v >= 0) then
  begin
    disc := self.radius2 - (eo.dot(eo) - (v * v));
    if (disc >= 0) then
    begin
      dist := v - Sqrt(disc);
    end;
  end;

  if (dist = 0) then
    Result := nil
  else
  begin
    Result := Intersection.Create(self, ray, dist);
  end;

end;

function Sphere.normal(pos: Vector): Vector;
begin
  Result := (pos - self.center).norm;
end;

function Sphere.surface: Surface;
begin
  Result := self._surface;
end;

{ ShinySurface }

function ShinySurface.diffuse(pos: Vector): Color;
begin
  Result := Color.white;
end;

function ShinySurface.reflect(pos: Vector): Double ;
begin
  Result := 0.7;
end;

function ShinySurface.roughness: Double ;
begin
  Result := 250;
end;

function ShinySurface.specular(pos: Vector): Color;
begin
  Result := Color.grey;
end;

{ CheckerboardSurface }
function CheckerboardSurface.diffuse(pos: Vector): Color;
begin
  if ((floor(pos.z) + floor(pos.x)) mod 2) <> 0 then
    Result := Color.white
  else
    Result := Color.black;
end;

function CheckerboardSurface.reflect(pos: Vector): Double ;
begin
  if ((floor(pos.z) + floor(pos.x)) mod 2) <> 0 then
    Result := 0.1
  else
    Result := 0.7;
end;

function CheckerboardSurface.roughness: Double ;
begin
  Result := 150.0;
end;

function CheckerboardSurface.specular(pos: Vector): Color;
begin
  Result := Color.white;
end;

{ Plane }

constructor Plane.Create(norm: Vector; offset: Double ; surface: Surface);
begin
  self.norm := norm;
  self.offset := offset;
  self._surface := surface;
end;

function Plane.intersect(ray: Ray): Intersection;
var
  dist, denom : Double ;
begin
  denom := self.norm.dot(ray.dir);
  if (denom > 0) then
  begin
    Result := nil;
  end else
  begin
    dist := (norm.dot(ray.start) + offset) / (-denom);
    Result := Intersection.Create(self, ray, dist);
  end;

end;

function Plane.normal(pos: Vector): Vector;
begin
  Result := self.norm;
end;

function Plane.surface: Surface;
begin
  result := _surface;
end;

{ RayTracerEngine }

constructor RayTracerEngine.Create;
begin
  Self.maxDepth := 5;
end;

function RayTracerEngine.getNaturalColor(thing: Thing; pos, norm, rd: Vector;
  scene: Scene): Color;


  function addLight(col:Color;light:Light):Color;
  var
    ldis, livec :Vector;
    testRay:Ray;
    neatIsect: Double ;
    isInShadow:Boolean;
    illum,specular:Double ;
    lcolor,scolor:Color;

  begin
      ldis      := light.pos - pos;
      livec     := ldis.norm;

      testRay   := Ray.Create(pos,livec);
      neatIsect := self.testRay(testRay, scene);
      testRay.Free;

      if (IsNan(neatIsect)) then
        isInShadow := false
      else
        isInShadow := (neatIsect <= ldis.mag);

      if isInShadow then exit(col);
      illum := livec.dot(norm);

      if illum > 0 then
        lcolor :=  illum * light.color
      else
        lcolor := Color.defaultColor;

      specular := livec.dot(rd.norm);

      if specular > 0 then
        scolor := Math.Power(specular,thing.surface.roughness) * light.color
      else
        scolor := Color.defaultColor;

      Result :=  col + ((thing.surface.diffuse(pos)  * lcolor) +
                        (thing.surface.specular(pos) * scolor));
  end;
var
  c:Color;
  i,n:Integer;
  lights:TList<Light>;
begin

  c := Color.defaultColor;
  n := scene.lights.Count -1;
  lights := scene.lights;

  for i:= 0 to n do
  begin
    c := addLight(c, lights.Items[i] );
  end;
  Result := c;

end;

function RayTracerEngine.getReflectionColor(thing: Thing; pos, normal,
  rd: Vector; scene: Scene; depth: integer): Color;
var
  r:Ray;
begin

  r := Ray.Create(pos, rd);
  Result :=  thing.surface.reflect(pos) * self.traceRay(r, scene, depth+1);
  r.Free;

end;

function RayTracerEngine.intersections(ray: Ray; scene: Scene): Intersection;
var
  closest:Double ;
  inter,closestInter: Intersection;
  i,n:Integer;

begin
  closest := MaxInt;
  closestInter := nil;
  n := scene.things.Count-1;

  for i := 0 to n do
  begin
    inter := scene.things.Items[i].intersect(ray);
    if (inter <> nil) and (inter.dist < closest) then
    begin
      if closestInter <> nil then closestInter.Free;
      
      closestInter := inter;
      closest := inter.dist;
    end;
  end;
  result := closestInter;
end;

procedure RayTracerEngine.render(scene: Scene; img: Graphics.TBitmap);
  var
    x,y,w,h : Integer;
    destColor  : Color;
    testRay    : Ray;
    c       : RGBColor;
    stride, pos  : Integer;
    start   : PBYTE;

  function getPoint(x,y:Integer; camera:Camera):Vector;
  var
    recenterX, recenterY:Double ;
  begin
      recenterX := (x - (w / 2.0)) / 2.0 / w;
      recenterY :=  - (y - (h / 2.0)) / 2.0 / h;
      Result :=(camera.forwardDir + ((recenterX * camera.right) + (recenterY * camera.up ))).norm();
  end;
begin

  w := img.Width -1;
  h := img.Height -1;

  start  := img.ScanLine[0];
  stride := integer(img.ScanLine[1]) - integer(img.ScanLine[0]);
  testRay   := Ray.Create();

  for y := 0 to h do
  begin
    for x := 0 to w do
    begin
      testRay.start := scene.xcamera.pos;
      testRay.dir := getPoint(x, y, scene.xcamera);
      
      destColor := self.traceRay(testRay, scene, 0);
      c := destColor.ToDrawingColor;
      
      pos := y*stride + x*4;
      start[pos]   := c.b;
      start[pos+1] := c.g;
      start[pos+2] := c.r;
    end;
    Writeln('Y = ' + IntToStr(y));
  end;

  testRay.Free;
end;

function RayTracerEngine.shade(isect: Intersection; scene: Scene; depth: integer): Color;
var
  d:Vector;
  pos, normal,reflectDir:Vector;
  naturalColor,reflectedColor:Color;

begin
  d   := isect.ray.dir;
  pos := (isect.dist * d) + isect.ray.start;
  normal := isect.thing.normal(pos);
  reflectDir := d - (2.0 * normal.dot(d) * normal);

  naturalColor := Color.background + self.getNaturalColor(isect.thing, pos, normal, reflectDir, scene);

 if depth >= self.maxDepth then
    reflectedColor := Color.grey
 else
    reflectedColor := self.getReflectionColor(isect.thing, pos, normal, reflectDir, scene, depth);

 Result := naturalColor + reflectedColor;
end;


function RayTracerEngine.testRay(ray: Ray; scene: Scene): Double ;
var
  isect: Intersection;
begin
  isect := self.intersections(ray, scene);
  if isect <> nil then
  begin
    exit(isect.dist);
  end;
  Result := NaN;
end;

function RayTracerEngine.traceRay(ray: Ray; scene: Scene; depth: integer): Color;
var
  isect:Intersection;
begin
  isect := self.intersections(ray, scene);
  if (isect = nil) then
  begin
    Result := Color.background;
  end else
  begin
    Result := self.shade(isect, scene, depth);
  end;
  isect.Free;
end;

{ Scene }

constructor Scene.Create;
var
  shiny:ShinySurface;
  checkerboard:CheckerboardSurface;
begin

  things := TList<Thing>.Create();
  lights := TList<Light>.Create();

  shiny := ShinySurface.Create;
  checkerboard := CheckerboardSurface.Create;

  things.Add( Plane.Create (Vector.Create(0.0, 1.0, 0.0), 0.0, checkerboard));
  things.Add( Sphere.Create(Vector.Create(0.0, 1.0, -0.25), 1.0, shiny));
  things.Add( Sphere.Create(Vector.Create(-1.0, 0.5, 1.5), 0.5, shiny));

  lights.Add(Light.Create(Vector.Create(-2.0, 2.5, 0.0), Color.Create(0.49, 0.07, 0.07)));
  lights.Add(Light.Create(Vector.Create(1.5, 2.5, 1.5),  Color.Create(0.07, 0.07, 0.49)));
  lights.Add(Light.Create(Vector.Create(1.5, 2.5, -1.5), Color.Create(0.07, 0.49, 0.071)));
  lights.Add(Light.Create(Vector.Create(0.0, 3.5, 0.0),  Color.Create(0.21, 0.21, 0.35)));

  self.xcamera := Camera.Create(Vector.Create(3.0, 2.0, 4.0), Vector.Create(-1.0, 0.5, 0.0));

end;

initialization
  Color.white := Color.Create(1,1,1);
  Color.grey  := Color.Create(0.5,0.5,0.5);
  Color.black := Color.Create(0,0,0);

  Color.defaultColor := Color.black;
  Color.background   := Color.black;
end.