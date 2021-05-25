module ModRaytracer
    implicit none

    real, parameter :: FarAway = 1000000.0d+0

    integer, parameter :: SHINY_SURFACE = 1
    integer, parameter :: CHECKERBOARD_SURFACE = 2

    integer, parameter :: SPHERE = 1
    integer, parameter :: PLANE = 2

    type TVector
        real(8) x
        real(8) y
        real(8) z
    end type

    type TColor
        real(8) r
        real(8) g
        real(8) b
    end type

    type TColorRGB
        integer(1)  b
        integer(1)  g
        integer(1)  r
        integer(1)  a
    end type

    type(TColor), parameter :: white        = TColor(1.0, 1.0, 1.0)
    type(TColor), parameter :: grey         = TColor(0.5, 0.5, 0.5)
    type(TColor), parameter :: black        = TColor(0.0, 0.0, 0.0)
    type(TColor), parameter :: background   = TColor(0.0, 0.0, 0.0)
    type(TColor), parameter :: defaultColor = TColor(0.0, 0.0, 0.0)

    type TCamera
        type(TVector) forward, right, up, pos
    end type

    type TRay
        type(TVector) :: start, dir
    end type

    type TSurface
        integer type
        type(TColor) :: diffuse, specular
        real(8)      :: reflect, roughness
    end type

    type TThing
        integer type
        integer surfaceType
        type(TVector) :: centerOrNormal
        real(8)       :: radiusOrOffset
    end type

    type TIntersection
        type(TThing) :: thing
        type(TRay)   :: ray
        real(8)      :: dist
        logical      :: isValid
    end type

    type TLight
        type(TVector) :: pos
        type(TColor)  :: color
    end type

    type TScene
        integer    maxDepth
        type(TThing), ALLOCATABLE :: things(:)
        type(TLight), ALLOCATABLE :: lights(:)
        type(TCamera) camera
    end type

    type BmpFileHeader
        character(2) bfType
        integer(4) bfSize
        integer(4) bfReserved ! actually Reserved1 & 2
        integer(4) bfOffBits
    end type

    type BmpInfoHeader
        integer*4 biSize
        integer*4 biWidth
        integer*4 biHeight
        integer*2 biPlanes
        integer*2 biBitCount
        integer*4 biCompression
        integer*4 biSizeImage
        integer*4 biXPelsPerMeter
        integer*4 biYPelsPerMeter
        integer*4 biClrUsed
        integer*4 biClrImportant
    end type

    type TSurfaceProperties
        real(8)  reflect
        real(8)  roughness
        type(TColor) :: diffuse
        type(TColor) :: specular
    end type

    interface operator (+)
        module procedure VectorAdd
        module procedure ColorAdd
    end interface

    interface operator (-)
        module procedure VectorSub
    end interface

    interface operator (*)
        module procedure VectorScale
        module procedure ColorScale
        module procedure ColorMul
    end interface

    interface operator (.dot.)
        module procedure VectorDot
    end interface

    interface operator (.cross.)
        module procedure VectorCross
    end interface

contains
    function VectorDot(a, b)
        type(TVector), intent(in)  :: a, b
        real(8) VectorDot
        VectorDot = a%x * b%x + a%y * b%y + a%z * b%z
    end function

    function VectorCross(a, b)
        type(TVector), intent(in)  :: a, b
        type(TVector) :: VectorCross

        VectorCross%x =  a%y * b%z - a%z * b%y
        VectorCross%y =  a%z * b%x - a%x * b%z
        VectorCross%z =  a%x * b%y - a%y * b%x
    end function

    function VectorAdd(a, b)
        type(TVector), intent(in)  :: a, b
        type(TVector) :: VectorAdd

        VectorAdd%x = a%x + b%x
        VectorAdd%y = a%y + b%y
        VectorAdd%z = a%z + b%z
    end function

    function VectorSub(a, b)
        type(TVector), intent(in)  :: a, b
        type(TVector) :: VectorSub

        VectorSub%x = a%x - b%x
        VectorSub%y = a%y - b%y
        VectorSub%z = a%z - b%z
    end function

    pure function VectorScale(a, k)
        type(TVector), intent(in) :: a
        type(TVector) :: VectorScale
        real(8), intent(in) :: k

        VectorScale%x = a%x * k
        VectorScale%y = a%y * k
        VectorScale%z = a%z * k
    end function

    pure function VectorLength(vec) result(value)
        type(TVector), intent(in) :: vec
        real(8) :: value
        value = sqrt(vec%x ** 2 + vec%y ** 2 + vec%z ** 2 )
    end function

    pure function VectorNorm(vec)
        type(TVector), intent(in)  :: vec
        type(TVector):: VectorNorm
        real(8) :: mag, div

        mag   = VectorLength(vec)

        if(mag == 0.0) then
            div = FarAway
        else
            div = 1.0d+0 / mag
        endif

        VectorNorm = vec * div
    end function

    pure function clampInt(color)
        real(8), intent(in) :: color
        integer :: v
        integer(1) :: clampInt

        v = int(color*255.0d+0)

        if (v > 255) then
            v = 255
        else if (v < 0) then
            v = 0
        endif

        clampInt = int(v, kind=1)
    end function

    function ColorAdd(a, b)
        type(TColor), intent(in)  :: a, b
        type(TColor) :: ColorAdd
        ColorAdd%r = a%r + b%r
        ColorAdd%g = a%g + b%g
        ColorAdd%b = a%b + b%b
    end function

    function ColorScale(a, k)
        type(TColor), intent(in) :: a
        type(TColor) :: ColorScale
        real(8), intent(in) :: k

        ColorScale%r = a%r * k
        ColorScale%g = a%g * k
        ColorScale%b = a%b * k
    end function

    function ColorMul(a, b)
        type(TColor), intent(in) :: a, b
        type(TColor) :: ColorMul

        ColorMul%r = a%r * b%r
        ColorMul%g = a%g * b%g
        ColorMul%b = a%b * b%b
    end function

    function ColorToRGB(c) result(value)
        type(TColor), intent(in) :: c
        type(TColorRGB) :: value

        value%b = clampInt(c%b)
        value%g = clampInt(c%g)
        value%r = clampInt(c%r)
        value%a = clampInt(1.0d+0)
    end function

    function ObjectIntersect(object, rayDir) result(value)
        type(TThing), intent(in) :: object
        type(TRay), intent(in) :: rayDir
        type(TIntersection) :: value
        real(8) :: v, dist, disc, denom
        type(TVector) :: eo

        value%isValid = .false.

        select case (object%type)
            case (SPHERE)
                eo = object%centerOrNormal - rayDir%start
                v =  eo .dot. rayDir%dir
                dist = 0

                if (v >= 0) then
                    disc = object%radiusOrOffset - ((eo .dot. eo) - (v * v))
                    if (disc >= 0) then
                        dist = v - sqrt(disc)
                    end if
                end if
                if (dist /= 0.0) then
                    value%thing = object
                    value%ray   = rayDir
                    value%dist  = dist
                    value%isValid = .true.
                end if
            case (PLANE)
                denom = object%centerOrNormal .dot. rayDir%dir
                if (denom <= 0) then
                    value%dist = ((object%centerOrNormal .dot. rayDir%start) + object%radiusOrOffset) / (-denom)
                    value%thing = object
                    value%ray = rayDir
                    value%isValid = .true.
                end if
        end select
    end function

    function CreateSphere(center, radius, surface) result(value)
        type(TVector), intent(in) :: center
        real(8), intent(in) :: radius
        integer surface
        type(TThing) :: value

        value%type = SPHERE
        value%surfaceType = surface
        value%centerOrNormal = center
        value%radiusOrOffset  = radius * radius
    end function

    function CreatePlane(normal, offset, surface) result(value)
        type(TVector), intent(in) :: normal
        real(8), intent(in) :: offset
        integer surface
        type(TThing) :: value

        value%type = PLANE
        value%surfaceType = surface
        value%centerOrNormal = normal
        value%radiusOrOffset  = offset
    end function

    function Intersections(ray, scene) result(value)
        type(TRay) :: ray
        type(TScene) :: scene
        type(TIntersection) :: inter, value
        real(8) closest
        integer i

        closest = FarAway
        value%isValid = .false.

        do i = 1, ubound(scene%things, 1)
            inter = ObjectIntersect(scene%things(i) , ray)
            if (inter%isValid .and. inter%dist < closest) then
                value = inter
                closest = inter%dist
            end if
        end do
    end function

    function TraceRay(ray, scene, depth) result(value)
        type(TRay), intent(in) :: ray
        type(TScene), intent(in) :: scene
        type(TIntersection) :: isect
        integer, intent(in) :: depth
        type (TColor)  :: value

        isect = Intersections(ray, scene)
        value = merge(Shade(isect, scene, depth), background, isect%isValid)
    end function

    function GetSurfaceProperties(surface, pos) result(properties)
        type(TSurfaceProperties) :: properties
        type(TVector) :: pos
        integer val, surface

        if (surface .eq. SHINY_SURFACE) then
            properties = TSurfaceProperties(0.7, 250, white, grey)
        else
            val = (floor(pos%z) + floor(pos%x))

            if (mod(val,2) /= 0) then
                properties%reflect   = 0.1
                properties%diffuse   = white
            else
                properties%reflect   = 0.7
                properties%diffuse   = black
            end if
            properties%specular  = white
            properties%roughness = 150.0
        end if
    end function

    function GetReflectionColor(thing, pos, rd, scene, depth) result(value)
        type (TColor)  :: color, value
        type (TThing), intent (in) ::thing
        type (TVector) :: rd, pos
        type (TScene) :: scene
        type (TSurfaceProperties) :: surface
        integer depth

        color = TraceRay(TRay(pos, rd), scene, depth + 1)
        surface = GetSurfaceProperties(thing%surfaceType, pos)
        value = (color * surface%reflect)
    end function

    function GetNaturalColor(thing, pos, normal, rd, scene) result(value)
        type (TColor)  :: value, lcolor, scolor
        type (TThing), intent (in) ::thing
        type (TVector) :: normal, rd, pos, ldis, livec, rdNorm
        type (TScene) :: scene
        type (TRay) :: ray
        type (TLight) :: light
        type (TSurfaceProperties) :: surface
        integer :: i
        real(8) :: ldisLen, illum, specular
        logical :: isInShadow
        type(TIntersection) :: isect

        value = black
        surface = GetSurfaceProperties(thing%surfaceType, pos)
        rdNorm = VectorNorm(rd)

        do i = 1,  ubound(scene%lights, 1)
            light = scene%lights(i)
            ldis  = light%pos - pos
            livec = VectorNorm(ldis)

            ldisLen = VectorLength(ldis)
            ray = TRay(pos, livec)
            isect = Intersections(ray, scene)
            isInShadow = (isect%isValid) .and. (isect%dist <= ldisLen)

            if (isInShadow .eqv. .false. ) then
                illum   =  (livec .dot. normal)
                specular = (livec .dot. rdNorm)

                lcolor = merge(light%color * illum, defaultColor, illum > 0)
                scolor = merge(light%color * specular ** surface%roughness, defaultColor, specular > 0)

                lcolor = (lcolor * surface%diffuse)
                scolor = (scolor * surface%specular)
                value = value + lcolor + scolor
            end if
        end do
    end function

    function ObjectNormal(thing, pos) result (value)
        type(TVector) value
        type(TThing) thing
        type(TVector) pos
        value = merge(VectorNorm(pos - thing%centerOrNormal), thing%centerOrNormal, thing%type == SPHERE)
    end function

    function Shade(isect, scene, depth) result(value)
        type(TIntersection) :: isect
        type(TScene)  :: scene
        type(TVector) :: d, pos, normal, reflectDir
        type(TColor)  :: value, naturalColor, reflectedColor
        integer       :: depth

        d = isect%ray%dir
        pos = (d * isect%dist) + isect%ray%start
        normal = ObjectNormal(isect%thing, pos)
        reflectDir = d - (normal * ((normal .dot. d) * 2))

        naturalColor = background + GetNaturalColor(isect%thing, pos, normal, reflectDir, scene)

        if (depth >= scene%maxDepth) then
            reflectedColor = grey
        else
            reflectedColor = GetReflectionColor(isect%thing, pos, reflectDir, scene, depth)
        end if

        value = naturalColor + reflectedColor
    end function

    function GetPoint(x, y, camera, screenWidth, screenHeight) result (value)
        integer       :: x, y, screenWidth, screenHeight
        type(TCamera) :: camera
        type(TVector) :: vx, vy, value
        real(8)       :: recenterX, recenterY

        recenterX =  (x - (screenWidth  / 2.0)) / 2.0 / screenWidth
        recenterY = -(y - (screenHeight / 2.0)) / 2.0 / screenHeight

        vx = camera%right * recenterX
        vy = camera%up * recenterY

        value = VectorNorm(camera%forward + vx + vy)
    end function

    subroutine RenderScene(scene, bitmapData, stride, w, h)
        type(TScene) :: scene
        integer stride, w, h, x, y, index
        type(TColor) :: color
        type(TColorRGB), dimension(:), intent(inout) :: bitmapData(:)
        type(TRay) :: ray;

        ray = TRay(scene%camera%pos, TVector(0.0, 0.0, 0.0))

        do y = 0 , h - 1
            index = y * stride
            do  x = 0 , w - 1
                ray%dir = GetPoint(x, y, scene%camera, h, w)
                color = TraceRay(ray, scene, 0)
                bitmapData(index + x + 1) = ColorToRGB(color)
            end do
        end do
    end subroutine

    function CreateCamera(pos, lookAt) result (camera)
        type (TCamera) camera
        type (TVector) pos, lookAt, down, forward, rightNorm, upNorm

        camera%pos = pos
        down       = TVector(0.0, -1.0, 0.0)
        forward    = lookAt - pos

        camera%forward  = VectorNorm(forward)
        camera%right    = camera%forward .cross. down
        camera%up       = camera%forward .cross. camera%right

        rightNorm = VectorNorm(camera%right)
        upNorm    = VectorNorm(camera%up)

        camera%right = rightNorm * 1.5d+0
        camera%up = upNorm * 1.5d+0
    end function

    subroutine SaveRGBBitmap(image, lWidth, lHeight)
        type(BmpInfoHeader) :: infoHeader
        type(BmpFileHeader) :: fileHeader
        integer :: lWidth, lHeight
        type(TColorRGB), dimension(:), intent(in) :: image

        infoHeader%biSize = 40
        infoHeader%biBitCount = 32
        infoHeader%biClrImportant = 0
        infoHeader%biClrUsed = 0
        infoHeader%biCompression = 0
        infoHeader%biHeight = -lHeight
        infoHeader%biWidth  = lWidth
        infoHeader%biPlanes = 1
        infoHeader%biSizeImage = lWidth * lHeight * 4

        fileHeader%bfType    = 'BM'
        fileHeader%bfOffBits = 54
        fileHeader%bfSize    = fileHeader%bfOffBits + infoHeader%biSizeImage

        open (unit = 1, file = 'RayTracer.bmp', status = 'unknown', access = 'STREAM')
        write (1) fileHeader
        write (1) infoHeader
        write (1) image
        close(1)

    end subroutine
end module

program RayTracerProgram
    use ModRaytracer
    implicit none

    real :: timeStart, timeEnd
    type(TScene)   :: scene
    type(TColorRGB), dimension(:) :: bitmap(500 * 500)


    call cpu_time(timeStart)

    allocate(scene%things(3))
    allocate(scene%lights(4))

    scene%maxDepth = 5
    scene%things(1) = CreatePlane (TVector( 0.0, 1.0,  0.0 ), 0.0d+0, CHECKERBOARD_SURFACE)
    scene%things(2) = CreateSphere(TVector( 0.0, 1.0, -0.25), 1.0d+0, SHINY_SURFACE)
    scene%things(3) = CreateSphere(TVector(-1.0, 0.5,  1.5 ), 0.5d+0, SHINY_SURFACE)

    scene%lights(1) = TLight(TVector(-2.0, 2.5, 0.0), TColor(0.49, 0.07, 0.07))
    scene%lights(2) = TLight(TVector(1.5, 2.5, 1.5),  TColor(0.07, 0.07, 0.49))
    scene%lights(3) = TLight(TVector(1.5, 2.5, -1.5), TColor(0.07, 0.49, 0.071))
    scene%lights(4) = TLight(TVector(0.0, 3.5, 0.0),  TColor(0.21, 0.21, 0.35))

    scene%camera    = CreateCamera(TVector(3.0, 2.0, 4.0), TVector(-1.0, 0.5, 0.0))

    call RenderScene(scene, bitmap, 500, 500, 500)

    deallocate(scene%things)
    deallocate(scene%lights)

    call cpu_time(timeEnd)

    print '("Render time: ",f8.2," ms.")', (timeEnd - timeStart) * 1000


    call SaveRGBBitmap(bitmap, 500, 500)

end program