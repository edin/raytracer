Module RayTracer
    Sub Main()
        Dim bmp As Drawing.Bitmap = New Drawing.Bitmap(500, 500, Drawing.Imaging.PixelFormat.Format32bppArgb)
        Dim sw As New Stopwatch()

        Console.WriteLine("VB.Net RayTracer Test")

        sw.Start()
        Dim rayTracer As New RayTracerEngine()
        Dim scene As New DefaultScene()
        rayTracer.render(scene, bmp)
        sw.Stop()

        bmp.Save("vb-ray-tracer.png")

        Console.WriteLine("")
        Console.WriteLine("Total time: " + sw.ElapsedMilliseconds.ToString() + " ms")
    End Sub
End Module

Class Vector
    Public x As Double
    Public y As Double
    Public z As Double

    Public Sub New(x As Double, y As Double, z As Double)
        Me.x = x
        Me.y = y
        Me.z = z
    End Sub

    Public Shared Operator -(v1 As Vector, v2 As Vector) As Vector
        Return New Vector(v1.x - v2.x, v1.y - v2.y, v1.z - v2.z)
    End Operator

    Public Shared Function dot(v1 As Vector, v2 As Vector) As Double
        Return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
    End Function

    Public Shared Function mag(v As Vector) As Double
        Return Math.Sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    End Function

    Public Shared Operator +(v1 As Vector, v2 As Vector) As Vector
        Return New Vector(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z)
    End Operator

    Public Shared Operator *(k As Double, v As Vector) As Vector
        Return New Vector(k * v.x, k * v.y, k * v.z)
    End Operator

    Public Shared Function norm(v As Vector) As Vector
        Dim mag = Vector.mag(v)
        Dim div = If((mag = 0), Double.PositiveInfinity, 1.0 / mag)
        Return div * v
    End Function

    Public Shared Function cross(v1 As Vector, v2 As Vector) As Vector
        Return New Vector(v1.y * v2.z - v1.z * v2.y,
                          v1.z * v2.x - v1.x * v2.z,
                          v1.x * v2.y - v1.y * v2.x)
    End Function
End Class

Class Color
    Public r As Double
    Public g As Double
    Public b As Double

    Public Shared white As Color = New Color(1.0, 1.0, 1.0)
    Public Shared grey As Color = New Color(0.5, 0.5, 0.5)
    Public Shared black As Color = New Color(0.0, 0.0, 0.0)
    Public Shared background As Color = Color.black
    Public Shared defaultcolor As Color = Color.black

    Public Sub New(r As Double, g As Double, b As Double)
        Me.r = r
        Me.g = g
        Me.b = b
    End Sub

    Public Shared Operator *(k As Double, v As Color) As Color
        Return New Color(k * v.r, k * v.g, k * v.b)
    End Operator

    Public Shared Operator +(v1 As Color, v2 As Color) As Color
        Return New Color(v1.r + v2.r, v1.g + v2.g, v1.b + v2.b)
    End Operator

    Public Shared Operator *(v1 As Color, v2 As Color) As Color
        Return New Color(v1.r * v2.r, v1.g * v2.g, v1.b * v2.b)
    End Operator

    Public Shared Function toDrawingColor(c As Color) As System.Drawing.Color
        Return System.Drawing.Color.FromArgb(Clamp(c.r), Clamp(c.g), Clamp(c.b))
    End Function

    Public Shared Function Clamp(c As Double) As Byte
        Dim v As Integer = CInt(c * 255)
        If (v > 255) Then Return 255
        If (v < 0) Then Return 0
        Return CType(v, Byte)
    End Function
End Class

Class Camera
    Public forward As Vector
    Public right As Vector
    Public up As Vector
    Public pos As Vector

    Public Sub New(pos As Vector, lookAt As Vector)
        Dim down = New Vector(0.0, -1.0, 0.0)
        Me.pos = pos
        Me.forward = Vector.norm(lookAt - Me.pos)
        Me.right = 1.5 * Vector.norm(Vector.cross(Me.forward, down))
        Me.up = 1.5 * Vector.norm(Vector.cross(Me.forward, Me.right))
    End Sub
End Class

Class Ray
    Public start As Vector
    Public dir As Vector

    Public Sub New(start As Vector, dir As Vector)
        Me.start = start
        Me.dir = dir
    End Sub
End Class

Class Intersection
    Public thing As Thing
    Public ray As Ray
    Public dist As Double

    Public Sub New(thing As Thing, ray As Ray, dist As Double)
        Me.thing = thing
        Me.ray = ray
        Me.dist = dist
    End Sub
End Class

Interface Surface
    Function diffuse(pos As Vector) As Color
    Function specular(pos As Vector) As Color
    Function reflect(pos As Vector) As Double
    Property roughness As Double
End Interface

Interface Thing
    Function intersect(ray As Ray) As Intersection
    Function normal(pos As Vector) As Vector
    Property surface As Surface
End Interface

Class Light
    Public pos As Vector
    Public color As Color

    Public Sub New(pos As Vector, color As Color)
        Me.pos = pos
        Me.color = color
    End Sub
End Class

Interface Scene
    Function things() As List(Of Thing)
    Function lights() As List(Of Light)
    Property camera As Camera
End Interface

Class Sphere
    Implements Thing

    Private radius2 As Double
    Private center As Vector

    Public Sub New(center As Vector, radius As Double, surface As Surface)
        Me.radius2 = radius * radius
        Me.surface = surface
        Me.center = center
    End Sub

    Public Function intersect(ray As Ray) As Intersection Implements Thing.intersect

        Dim eo = (Me.center - ray.start)
        Dim v = Vector.dot(eo, ray.dir)
        Dim dist = 0.0

        If (v >= 0) Then
            Dim disc = Me.radius2 - (Vector.dot(eo, eo) - v * v)
            If (disc >= 0) Then
                dist = v - Math.Sqrt(disc)
            End If
        End If

        If (dist = 0) Then Return Nothing

        Return New Intersection(Me, ray, dist)
    End Function

    Public Function normal(pos As Vector) As Vector Implements Thing.normal
        Return Vector.norm(pos - Me.center)
    End Function

    Public Property surface As Surface Implements Thing.surface
End Class

Class Plane
    Implements Thing

    Private _normal As Vector
    Private _offset As Double

    Public Sub New(norm As Vector, offset As Double, surface As Surface)
        Me._normal = norm
        Me._offset = offset
        Me.surface = surface
    End Sub

    Public Function intersect(ray As Ray) As Intersection Implements Thing.intersect
        Dim denom = Vector.dot(Me._normal, ray.dir)
        If (denom > 0) Then Return Nothing

        Dim dist = (Vector.dot(Me._normal, ray.start) + Me._offset) / (-denom)
        Return New Intersection(Me, ray, dist)
    End Function

    Public Function normal(pos As Vector) As Vector Implements Thing.normal
        Return Me._normal
    End Function

    Public Property surface As Surface Implements Thing.surface
End Class

Class ShinySurface
    Implements Surface

    Public Function diffuse(pos As Vector) As Color Implements Surface.diffuse
        Return Color.white
    End Function

    Public Function reflect(pos As Vector) As Double Implements Surface.reflect
        Return 0.7
    End Function

    Public Property roughness As Double = 250 Implements Surface.roughness

    Public Function specular(pos As Vector) As Color Implements Surface.specular
        Return Color.grey
    End Function
End Class

Class CheckerboardSurface
    Implements Surface

    Public Function diffuse(pos As Vector) As Color Implements Surface.diffuse
        If (Math.Floor(pos.z) + Math.Floor(pos.x)) Mod 2 <> 0 Then
            Return Color.white
        Else
            Return Color.black
        End If
    End Function

    Public Function reflect(pos As Vector) As Double Implements Surface.reflect
        If (Math.Floor(pos.z) + Math.Floor(pos.x)) Mod 2 <> 0 Then
            Return 0.1
        Else
            Return 0.7
        End If
    End Function

    Public Property roughness As Double = 150 Implements Surface.roughness

    Public Function specular(pos As Vector) As Color Implements Surface.specular
        Return Color.white
    End Function
End Class

Class Surfaces
    Public Shared shiny As Surface = New ShinySurface()
    Public Shared checkerboard As Surface = New CheckerboardSurface()
End Class

Class DefaultScene
    Implements Scene
    Public Property camera As Camera Implements Scene.camera

    Private _lights As List(Of Light) = New List(Of Light)
    Private _things As List(Of Thing) = New List(Of Thing)

    Public Sub New()
        Me.camera = New Camera(New Vector(3.0, 2.0, 4.0), New Vector(-1.0, 0.5, 0.0))

        _things.Add(New Plane(New Vector(0.0, 1.0, 0.0), 0.0, Surfaces.checkerboard))
        _things.Add(New Sphere(New Vector(0.0, 1.0, -0.25), 1.0, Surfaces.shiny))
        _things.Add(New Sphere(New Vector(-1.0, 0.5, 1.5), 0.5, Surfaces.shiny))

        _lights.Add(New Light(New Vector(-2.0, 2.5, 0.0), New Color(0.49, 0.07, 0.07)))
        _lights.Add(New Light(New Vector(1.5, 2.5, 1.5), New Color(0.07, 0.07, 0.49)))
        _lights.Add(New Light(New Vector(1.5, 2.5, -1.5), New Color(0.07, 0.49, 0.071)))
        _lights.Add(New Light(New Vector(0.0, 3.5, 0.0), New Color(0.21, 0.21, 0.35)))
    End Sub

    Public Function lights() As List(Of Light) Implements Scene.lights
        Return _lights
    End Function

    Public Function things() As List(Of Thing) Implements Scene.things
        Return _things
    End Function
End Class

Class RayTracerEngine
    Private maxDepth As Integer = 5

    Private Function intersections(ray As Ray, scene As Scene) As Intersection
        Dim closest = Double.PositiveInfinity
        Dim closestInter As Intersection = Nothing

        For Each item As Thing In scene.things
            Dim inter = item.intersect(ray)
            If (inter IsNot Nothing AndAlso inter.dist < closest) Then
                closestInter = inter
                closest = inter.dist
            End If
        Next
        Return closestInter

    End Function

    Private Function testRay(ray As Ray, scene As Scene) As Double
        Dim isect As Intersection = Me.intersections(ray, scene)
        If (isect IsNot Nothing) Then
            Return isect.dist
        Else
            Return Double.NaN
        End If
    End Function

    Private Function traceRay(ray As Ray, scene As Scene, depth As Integer) As Color
        Dim isect As Intersection = Me.intersections(ray, scene)
        If (isect Is Nothing) Then Return Color.background
        Return Me.shade(isect, scene, depth)
    End Function

    Private Function shade(isect As Intersection, scene As Scene, depth As Integer) As Color
        Dim d As Vector = isect.ray.dir

        Dim pos = (isect.dist * d) + isect.ray.start
        Dim normal = isect.thing.normal(pos)
        Dim reflectDir = d - (2 * Vector.dot(normal, d) * normal)

        Dim naturalColor = Color.background + Me.getNaturalColor(isect.thing, pos, normal, reflectDir, scene)


        Dim reflectedColor = If(depth >= Me.maxDepth, Color.grey, Me.getReflectionColor(isect.thing, pos, normal, reflectDir, scene, depth))

        Return naturalColor + reflectedColor
    End Function

    Private Function getReflectionColor(thing As Thing, pos As Vector, normal As Vector, rd As Vector, scene As Scene, depth As Integer) As Color
        Return thing.surface.reflect(pos) * Me.traceRay(New Ray(pos, rd), scene, depth + 1)
    End Function


    Private Function getNaturalColor(thing As Thing, pos As Vector, norm As Vector, rd As Vector, scene As Scene) As Color

        Dim c As Color = Color.defaultcolor
        For Each item As Light In scene.lights()
            c = Me.addLight(c, item, pos, scene, norm, rd, thing)
        Next
        Return c

    End Function

    Private Function addLight(col As Color, light As Light, pos As Vector, scene As Scene, norm As Vector, rd As Vector, thing As Thing) As Color
        Dim ldis = light.pos - pos
        Dim livec = Vector.norm(ldis)
        Dim neatIsect = Me.testRay(New Ray(pos, livec), scene)

        Dim isInShadow = If(Double.IsNaN(neatIsect), False, (neatIsect <= Vector.mag(ldis)))
        If (isInShadow) Then Return col


        Dim illum = Vector.dot(livec, norm)
        Dim lcolor = If((illum > 0), illum * light.color, Color.defaultcolor)

        Dim specular = Vector.dot(livec, Vector.norm(rd))
        Dim scolor = If(specular > 0, (Math.Pow(specular, thing.surface().roughness) * light.color), Color.defaultcolor)

        Return col + (thing.surface.diffuse(pos) * lcolor) + (thing.surface.specular(pos) * scolor)
    End Function


    Delegate Function GetPointDelegate(x As Integer, y As Integer, camera As Camera) As Vector

    Public Sub render(scene As Scene, bmp As System.Drawing.Bitmap)
        Dim w As Integer = bmp.Width
        Dim h As Integer = bmp.Height
        Dim getPoint As GetPointDelegate = Function(x As Integer, y As Integer, camera As Camera) As Vector
                                               Dim recenterX = (x - (w / 2.0)) / 2.0 / w
                                               Dim recenterY = -(y - (h / 2.0)) / 2.0 / h
                                               Return Vector.norm(camera.forward + (recenterX * camera.right) + (recenterY * camera.up))
                                           End Function

        Dim bitmapData As Drawing.Imaging.BitmapData = bmp.LockBits(New Drawing.Rectangle(0, 0, w, h), Drawing.Imaging.ImageLockMode.ReadWrite, bmp.PixelFormat)
        Dim stride As Integer = bitmapData.Stride
        Dim rgbData() As Byte
        Dim size As Integer = stride * h
        ReDim rgbData(size)

        System.Runtime.InteropServices.Marshal.Copy(bitmapData.Scan0, rgbData, 0, size)

        For y = 0 To h - 1
            For x = 0 To w - 1
                Dim color As Color = Me.traceRay(New Ray(scene.camera.pos, getPoint(x, y, scene.camera)), scene, 0)
                Dim c As Drawing.Color = color.toDrawingColor(color)

                Dim pos = y * stride + x * 4

                rgbData(pos) = c.B
                rgbData(pos + 1) = c.G
                rgbData(pos + 2) = c.R
                rgbData(pos + 3) = 255
            Next
        Next

        System.Runtime.InteropServices.Marshal.Copy(rgbData, 0, bitmapData.Scan0, size)
        bmp.UnlockBits(bitmapData)
    End Sub
End Class