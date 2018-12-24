module ModRaytracer
    implicit none

    real, parameter :: INF = 1000000.0d+0

    integer, parameter :: Red =1
    integer, parameter :: Green = 2
    integer, parameter :: Magenta = 3
    integer, parameter :: Blue = 4
    integer, parameter :: Violet = 5

    integer, parameter :: SHINY_SURFACE = 1
    integer, parameter :: CHECKERBOARD_SURFACE = 2

    integer, parameter :: SPHERE = 1
    integer, parameter :: PLANE = 2

    type Vector
        real(8) x
        real(8) y
        real(8) z
    end type

    type Color
        real r
        real g
        real b
    end type

    type ColorRGB
        integer r
        integer g
        integer b
    end type

    type(Color), parameter :: white        = Color(1.0, 1.0, 1.0)
    type(Color), parameter :: grey         = Color(0.5, 0.5, 0.5)
    type(Color), parameter :: black        = Color(0.0, 0.0, 0.0)
    type(Color), parameter :: background   = Color(0.0, 0.0, 0.0)
    type(Color), parameter :: defaultColor = Color(0.0, 0.0, 0.0)

    type Camera
        type(Vector) forward, right, up, pos;
    end type

    type Ray
        type(Vector) start, dir;
    end type

    type Surface
        integer type;
        type(Color) :: diffuse, specular;
        real(8)     :: reflect, roughness;
    end type

    type Thing
        integer type;
        type(Surface), pointer :: surface
        type(Vector)  :: centerOrNorm
        real(8)       :: radiusOrOffset
    end type

    type Intersection
        type(Thing), pointer :: thing
        type(Ray) :: ray
        real(8)   :: dist
    end type

    type Light
        type(Vector) :: pos
        type(Color)  :: color
    end type

    type Scene
        integer    maxDepth
        integer    thingCount
        integer    lightCount
        type(Thing), ALLOCATABLE  :: things(:)
        type(Light), ALLOCATABLE  :: lights(:)
        type(Camera) camera
    end type

    type SurfaceProperties
        real(8)  reflect
        real(8)  roughness
        type(Color) :: diffuse
        type(Color) :: specular
    end type

    interface operator (+)
        module procedure VectorAdd
        module procedure ColorAdd
    end interface

    interface operator (-)
        module procedure VectorSub
        module procedure ColorSub
    end interface

    interface operator (*)
        module procedure VectorMul
        module procedure ColorMul
    end interface

    interface operator (.dot.)
        module procedure VectorDot
    end interface

    interface operator (.cross.)
        module procedure VectorCross
    end interface

contains
    ! Vector type
    function VectorDot(a, b)
        type(Vector), intent(in)  :: a, b
        real(8) VectorDot
        VectorDot = a%x * b%x + a%y * b%y + a%z * b%z
    end function

    function VectorCross(a, b)
        type(Vector), intent(in)  :: a, b
        type(Vector) :: VectorCross

        VectorCross%x =  a%y * b%z - a%z * b%y
        VectorCross%y =  a%z * b%x - a%x * b%z
        VectorCross%z =  a%x * b%y - a%y * b%x
    end function

    function VectorAdd(a, b)
        type(Vector), intent(in)  :: a, b
        type(Vector) :: VectorAdd

        VectorAdd%x = a%x + b%x;
        VectorAdd%y = a%y + b%y;
        VectorAdd%z = a%z + b%z;
    end function

    function VectorSub(a, b)
        type(Vector), intent(in)  :: a, b
        type(Vector) :: VectorSub

        VectorSub%x = a%x - b%x;
        VectorSub%y = a%y - b%y;
        VectorSub%z = a%z - b%z;
    end function

    function VectorMul(a, k)
        type(Vector), intent(in) :: a
        type(Vector) :: VectorMul
        real(8), intent(in) :: k

        VectorMul%x = a%x * k;
        VectorMul%y = a%y * k;
        VectorMul%z = a%z * k;
    end function

    pure function Length(vec) result(value)
        type(Vector), intent(in) :: vec
        real(8) :: value
        value = sqrt(vec%x ** 2 + vec%y ** 2 + vec%z ** 2 )
    end function

    pure function Norm(vec)
        type(Vector), intent(in)  :: vec
        type(Vector):: Norm
        real(8) :: mag, div

        mag   = Length(vec)

        if(mag == 0.0) then
            div = INF
        else
            div = 1.0d+0 / mag
        endif

        Norm%x = vec%x / div
        Norm%y = vec%y / div
        Norm%z = vec%z / div
    end function


    ! Color type
    pure function clamp(color)
        real, intent(in) :: color
        real :: clamp, v
        v = int(color)
        if (v > 1.0) then
            clamp = 1.0
        else if (v < 0) then
            clamp = 0
        else
            clamp = v
        endif
    end function

    pure function clampInt(color)
        integer, intent(in) :: color
        integer :: clampInt, v
        v = int(color)
        if (v > 255) then
            clampInt = 255
        else if (v < 0) then
            clampInt = 0
        else
            clampInt = v
        endif
    end function

    function ColorAdd(a, b)
        type(Color), intent(in)  :: a, b
        type(Color) :: ColorAdd
        ColorAdd%r = a%r + b%r;
        ColorAdd%g = a%g + b%g;
        ColorAdd%b = a%b + b%b;
    end function

    function ColorSub(a, b)
        type(Color), intent(in)  :: a, b
        type(Color) :: ColorSub

        ColorSub%r = clamp(a%r - b%r);
        ColorSub%g = clamp(a%g - b%g);
        ColorSub%b = clamp(a%b - b%b);
    end function

    function ColorMul(a, k)
        type(Color), intent(in) :: a
        type(Color) :: ColorMul
        real, intent(in) :: k

        ColorMul%r = clamp(a%r * k);
        ColorMul%g = clamp(a%g * k);
        ColorMul%b = clamp(a%b * k);
    end function

    function ObjectIntersect(object, rayDir, result)
        type(Thing), intent(in) :: object
        type(Ray), intent(in) :: rayDir
        type(Intersection), intent(inout) :: result
        integer :: ObjectIntersect;
        real(8) :: v, dist, disc, denom
        type(Vector) :: eo

        ObjectIntersect = 0

        select case (object%type)
            case (SPHERE)
                eo = VectorSub(object%centerOrNorm, rayDir%start)
                v = VectorDot(eo, rayDir%dir)
                dist = 0

                if (v >= 0) then
                    disc = object%radiusOrOffset - (VectorDot(eo, eo) - (v * v));
                    if (disc >= 0) then
                        dist = v - sqrt(disc)
                    end if
                end if
                if (dist /= 0.0) then
                    result%thing = object;
                    result%ray   = rayDir;
                    result%dist  = dist;
                    ObjectIntersect = 1
                end if
            case (PLANE)
                denom = VectorDot(object%centerOrNorm, rayDir%dir);
                if (denom <= 0) then
                    result%dist = (VectorDot(object%centerOrNorm, rayDir%start) + object%radiusOrOffset) / (-denom);
                    result%thing = object;
                    result%ray = rayDir;
                    ObjectIntersect = 1
                end if
        end select
    end function

    ! Thing CreateSphere(Vector center, double radius, Surface *surface)
    ! {
    !     Thing sphere;
    !     sphere.type    = SPHERE;
    !     sphere.radius2 = radius * radius;
    !     sphere.center  = center;
    !     sphere.surface = surface;
    !     return sphere;
    ! }

    ! Thing CreatePlane(Vector norm, double offset, Surface *surface)
    ! {
    !     Thing plane;
    !     plane.type = PLANE;
    !     plane.surface = surface;
    !     plane.norm    = norm;
    !     plane.offset  = offset;
    !     return plane;
    ! }

    ! double TestRay(Ray *ray, Scene *scene)
    ! {
    !     Intersection isect = Intersections(ray, scene);
    !     if (isect.thing != NULL)
    !     {
    !         return isect.dist;
    !     }
    !     return NAN;
    ! }

    ! Color TraceRay(Ray *ray, Scene *scene, int depth)
    ! {
    !     Intersection isect = Intersections(ray, scene);
    !     if (isect.thing != NULL)
    !     {
    !         return Shade(&isect, scene, depth);
    !     }
    !     return background;
    ! }

    ! Color GetReflectionColor(Thing* thing, Vector *pos, Vector *normal, Vector *rd, Scene *scene, int depth)
    ! {
    !     Ray ray = CreateRay(*pos, *rd);
    !     Color color = TraceRay(&ray, scene, depth + 1);

    !     SurfaceProperties properties;
    !     GetSurfaceProperties(thing->surface, pos, &properties);

    !     return ScaleColor(&color, properties.reflect);
    ! }

    ! Color GetNaturalColor(Thing* thing, Vector *pos, Vector *norm, Vector *rd, Scene *scene)
    ! {
    !     Color resultColor = black;

    !     SurfaceProperties sp;
    !     GetSurfaceProperties(thing->surface, pos, &sp);

    !     int lightCount = scene->lightCount;

    !     Light *first = &scene->lights[0];
    !     Light *last  = &scene->lights[lightCount - 1];

    !     for (Light *light = first; light <= last; ++light)
    !     {
    !         Vector ldis  = VectorSub(&light->pos, pos);
    !         Vector livec = VectorNorm(ldis);

    !         double ldisLen = VectorLength(&ldis);
    !         Ray ray = { *pos, livec };

    !         double neatIsect = TestRay(&ray, scene);

    !         int isInShadow = (neatIsect == NAN) ? 0 : (neatIsect <= ldisLen);
    !         if (!isInShadow) {
    !             Vector rdNorm = VectorNorm(*rd);

    !             double illum   =  VectorDot(&livec, norm);
    !             double specular = VectorDot(&livec, &rdNorm);

    !             Color lcolor = (illum > 0) ?    ScaleColor(&light->color, illum) : defaultColor;
    !             Color scolor = (specular > 0) ? ScaleColor(&light->color, pow(specular, sp.roughness)) : defaultColor;

    !             ColorMultiplySelf(&lcolor, &sp.diffuse);
    !             ColorMultiplySelf(&scolor, &sp.specular);

    !             Color result = ColorAdd(&lcolor, &scolor);

    !             resultColor.r += result.r;
    !             resultColor.g += result.g;
    !             resultColor.b += result.b;
    !         }
    !     }
    !     return resultColor;
    ! }

    ! Color Shade(Intersection  *isect, Scene *scene, int depth)
    ! {
    !     Vector d = isect->ray.dir;
    !     Vector scaled = VectorScale(&d, isect->dist);

    !     Vector pos = VectorAdd(&scaled, &isect->ray.start);
    !     Vector normal = ObjectNormal(isect->thing, &pos);
    !     double nodmalDotD = VectorDot(&normal, &d);
    !     Vector normalScaled = VectorScale(&normal, nodmalDotD * 2);

    !     Vector reflectDir = VectorSub(&d, &normalScaled);

    !     Color naturalColor = GetNaturalColor(isect->thing, &pos, &normal, &reflectDir, scene);
    !     naturalColor = ColorAdd(&background, &naturalColor);

    !     Color reflectedColor = (depth >= scene->maxDepth) ? grey : GetReflectionColor(isect->thing, &pos, &normal, &reflectDir, scene, depth);

    !     return ColorAdd(&naturalColor, &reflectedColor);
    ! }

    ! Vector GetPoint(int x, int y, Camera *camera, int screenWidth, int screenHeight)
    ! {
    !     double recenterX = (x - (screenWidth / 2.0)) / 2.0 / screenWidth;
    !     double recenterY = -(y - (screenHeight / 2.0)) / 2.0 / screenHeight;

    !     Vector vx = VectorScale(&camera->right, recenterX);
    !     Vector vy = VectorScale(&camera->up, recenterY);

    !     Vector v = VectorAdd(&vx, &vy);
    !     Vector z = VectorAdd(&camera->forward, &v);

    !     z  = VectorNorm(z);
    !     return z;
    ! }

    ! void RenderScene(Scene *scene, byte* bitmapData, int stride, int w, int h)
    ! {
    !     Ray ray;
    !     ray.start = scene->camera.pos;
    !     for (int y = 0; y < h; ++y)
    !     {
    !         RgbColor* pColor = (RgbColor*)(&bitmapData[y * stride]);
    !         for (int x = 0; x < w; ++x)
    !         {
    !             ray.dir = GetPoint(x, y, &scene->camera, h, w);
    !             Color color = TraceRay(&ray, scene, 0);
    !             *pColor = ToDrawingColor(&color);
    !            ++pColor;
    !         }
    !     }
    ! }

    ! void SaveRGBBitmap(byte* pBitmapBits, int lWidth, int lHeight, int wBitsPerPixel, const char* lpszFileName)
    ! {
    !     BITMAPINFOHEADER bmpInfoHeader = {0};
    !     bmpInfoHeader.biSize = sizeof(BITMAPINFOHEADER);
    !     bmpInfoHeader.biBitCount = wBitsPerPixel;
    !     bmpInfoHeader.biClrImportant = 0;
    !     bmpInfoHeader.biClrUsed = 0;
    !     bmpInfoHeader.biCompression = BI_RGB;
    !     bmpInfoHeader.biHeight = -lHeight;
    !     bmpInfoHeader.biWidth  = lWidth;
    !     bmpInfoHeader.biPlanes = 1;
    !     bmpInfoHeader.biSizeImage = lWidth* lHeight * (wBitsPerPixel/8);

    !     BITMAPFILEHEADER bfh = {0};
    !     bfh.bfType = 'B' + ('M' << 8);
    !     bfh.bfOffBits = sizeof(BITMAPINFOHEADER) + sizeof(BITMAPFILEHEADER);
    !     bfh.bfSize    = bfh.bfOffBits + bmpInfoHeader.biSizeImage;

    !     FILE *hFile;
    !     hFile = fopen(lpszFileName, "wb");
    !     fwrite(&bfh, sizeof(char), sizeof(bfh), hFile);
    !     fwrite(&bmpInfoHeader, sizeof(char), sizeof(bmpInfoHeader), hFile);
    !     fwrite(pBitmapBits, sizeof(char), bmpInfoHeader.biSizeImage, hFile);
    !     fclose(hFile);
    ! }

end module


program hello
    use ModRaytracer
    implicit none

    type(Vector) :: a, b, c
    type(Scene)  :: s
    type(Surface) :: checkerboard, shiny

    allocate(s%things(3))
    allocate(s%lights(4))

    shiny%diffuse   = white;
    shiny%specular  = grey;
    shiny%reflect   = 0.7;
    shiny%roughness = 250.0;

    checkerboard%diffuse   = black;
    checkerboard%specular  = white;
    checkerboard%reflect   = 0.7;
    checkerboard%roughness = 150.0;

    !--------------------------------------------------------------------------------
    ! s%things(0) = CreatePlane (Vector( 0.0, 1.0,  0.0 ), 0.0, checkerboard);
    ! s%things(1) = CreateSphere(Vector( 0.0, 1.0, -0.25), 1.0, shiny);
    ! s%things(2) = CreateSphere(Vector(-1.0, 0.5,  1.5 ), 0.5, shiny);
    !
    ! scene%lights(0) = Light(Vector(-2.0, 2.5, 0.0), Color(0.49, 0.07, 0.07));
    ! scene%lights(1) = Light(Vector(1.5, 2.5, 1.5),  Color(0.07, 0.07, 0.49));
    ! scene%lights(2) = Light(Vector(1.5, 2.5, -1.5), Color(0.07, 0.49, 0.071));
    ! scene%lights(3) = Light(Vector(0.0, 3.5, 0.0),  Color(0.21, 0.21, 0.35));
    !--------------------------------------------------------------------------------

    a = Vector(5.0d+0, 8.0d+0, 2.0d+0)
    b = Vector(2.0d+0, 4.0d+0, 2.0d+0)

    c = a .cross. b

    print *, c%x, c%y, c%z

end program