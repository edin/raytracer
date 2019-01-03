Imports VBRayTracer

Module RayTracer
    Sub Main()
        Dim bmp As Drawing.Bitmap = New Drawing.Bitmap(500, 500, Drawing.Imaging.PixelFormat.Format32bppArgb)
        Dim sw As New Stopwatch()

        Console.WriteLine("VB.Net RayTracer Test")

        sw.Start()
        Dim rayTracer As New RayTracerEngine()
        Dim scene As New Scene()
        rayTracer.Render(scene, bmp)
        sw.Stop()

        bmp.Save("vb-ray-tracer.png")

        Console.WriteLine("")
        Console.WriteLine("Total time: " + sw.ElapsedMilliseconds.ToString() + " ms")
    End Sub
End Module

Structure Vector
    Public X As Double
    Public Y As Double
    Public Z As Double

    Public Sub New(x As Double, y As Double, z As Double)
        Me.X = x
        Me.Y = y
        Me.Z = z
    End Sub

    Public Shared Operator -(a As Vector, b As Vector) As Vector
        Return New Vector(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
    End Operator

    Public Shared Operator +(a As Vector, b As Vector) As Vector
        Return New Vector(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
    End Operator

    Public Shared Operator *(k As Double, v As Vector) As Vector
        Return New Vector(k * v.X, k * v.Y, k * v.Z)
    End Operator

    Public Function Dot(v As Vector) As Double
        Return X * v.X + Y * v.Y + Z * v.Z
    End Function

    Public Function Length() As Double
        Return Math.Sqrt(X * X + Y * Y + Z * Z)
    End Function

    Public Function Norm() As Vector
        Dim mag = Me.Length
        Dim div = If(mag = 0, Double.PositiveInfinity, 1.0 / mag)
        Return div * Me
    End Function

    Public Function Cross(v As Vector) As Vector
        Return New Vector(Y * v.Z - Z * v.Y,
                          Z * v.X - X * v.Z,
                          X * v.Y - Y * v.X)
    End Function
End Structure

Structure Color
    Public R As Double
    Public G As Double
    Public B As Double

    Public Shared White As Color = New Color(1.0, 1.0, 1.0)
    Public Shared Grey As Color = New Color(0.5, 0.5, 0.5)
    Public Shared Black As Color = New Color(0.0, 0.0, 0.0)
    Public Shared Background As Color = Color.Black
    Public Shared DefaultColor As Color = Color.Black

    Public Sub New(r As Double, g As Double, b As Double)
        Me.R = r
        Me.G = g
        Me.B = b
    End Sub

    Public Shared Operator *(k As Double, v As Color) As Color
        Return New Color(k * v.R, k * v.G, k * v.B)
    End Operator

    Public Shared Operator +(v1 As Color, v2 As Color) As Color
        Return New Color(v1.R + v2.R, v1.G + v2.G, v1.B + v2.B)
    End Operator

    Public Shared Operator *(v1 As Color, v2 As Color) As Color
        Return New Color(v1.R * v2.R, v1.G * v2.G, v1.B * v2.B)
    End Operator

    Public Function ToDrawingColor() As System.Drawing.Color
        Return System.Drawing.Color.FromArgb(Clamp(R), Clamp(G), Clamp(B))
    End Function

    Public Shared Function Clamp(c As Double) As Byte
        Dim v As Integer = CInt(c * 255)
        If (v > 255) Then Return 255
        If (v < 0) Then Return 0
        Return CType(v, Byte)
    End Function
End Structure

Class Camera
    Public Forward As Vector
    Public Right As Vector
    Public Up As Vector
    Public Pos As Vector

    Public Sub New(pos As Vector, lookAt As Vector)
        Dim down = New Vector(0.0, -1.0, 0.0)
        Me.Pos = pos

        Forward = (lookAt - Me.Pos).Norm
        Right = 1.5 * Forward.Cross(down).Norm
        Up = 1.5 * Forward.Cross(Right).Norm
    End Sub
End Class

Class Ray
    Public Start As Vector
    Public Dir As Vector

    Public Sub New(start As Vector, dir As Vector)
        Me.Start = start
        Me.Dir = dir
    End Sub
End Class

Class Intersection
    Public Thing As IThing
    Public Ray As Ray
    Public Dist As Double

    Public Sub New(thing As IThing, ray As Ray, dist As Double)
        Me.Thing = thing
        Me.Ray = ray
        Me.Dist = dist
    End Sub
End Class

Structure SurfaceProperties
    Public Diffuse As Color
    Public Specular As Color
    Public Reflect As Double
    Public Roughness As Double
End Structure

Interface ISurface
    Function GetSurfaceProperties(pos As Vector) As SurfaceProperties
End Interface

Interface IThing
    Function Intersect(ray As Ray) As Intersection
    Function Normal(pos As Vector) As Vector
    Property Surface As ISurface
End Interface

Class Light
    Public Pos As Vector
    Public Color As Color

    Public Sub New(pos As Vector, color As Color)
        Me.Pos = pos
        Me.Color = color
    End Sub
End Class

Class Sphere
    Implements IThing

    Private Radius2 As Double
    Private Center As Vector

    Public Sub New(center As Vector, radius As Double, surface As ISurface)
        Me.Radius2 = radius * radius
        Me.Surface = surface
        Me.Center = center
    End Sub

    Public Function Intersect(ray As Ray) As Intersection Implements IThing.Intersect

        Dim eo = (Me.Center - ray.Start)
        Dim v = eo.Dot(ray.Dir)
        Dim dist = 0.0

        If (v >= 0) Then
            Dim disc = Me.Radius2 - (eo.Dot(eo) - v * v)
            If (disc >= 0) Then
                dist = v - Math.Sqrt(disc)
            End If
        End If

        If (dist = 0) Then Return Nothing

        Return New Intersection(Me, ray, dist)
    End Function

    Public Function Normal(pos As Vector) As Vector Implements IThing.Normal
        Return (pos - Me.Center).Norm
    End Function

    Public Property Surface As ISurface Implements IThing.Surface
End Class

Class Plane
    Implements IThing

    Private Normal As Vector
    Private Offset As Double

    Public Sub New(normal As Vector, offset As Double, surface As ISurface)
        Me.Normal = normal
        Me.Offset = offset
        Me.Surface = surface
    End Sub

    Public Function Intersect(ray As Ray) As Intersection Implements IThing.Intersect
        Dim denom = Me.Normal.Dot(ray.Dir)
        If (denom > 0) Then Return Nothing

        Dim dist = (Me.Normal.Dot(ray.Start) + Me.Offset) / (-denom)
        Return New Intersection(Me, ray, dist)
    End Function

    Public Function GetNormal(pos As Vector) As Vector Implements IThing.Normal
        Return Me.Normal
    End Function

    Public Property Surface As ISurface Implements IThing.Surface
End Class

Class ShinySurface
    Implements ISurface

    Public Function GetSurfaceProperties(pos As Vector) As SurfaceProperties Implements ISurface.GetSurfaceProperties
        Return New SurfaceProperties With {
            .Specular = Color.Grey,
            .Diffuse = Color.White,
            .Reflect = 0.7,
            .Roughness = 250
        }
    End Function
End Class

Class CheckerboardSurface
    Implements ISurface

    Public Function GetSurfaceProperties(pos As Vector) As SurfaceProperties Implements ISurface.GetSurfaceProperties
        Dim diffuse = Color.Black
        Dim reflect = 0.7

        If (Math.Floor(pos.Z) + Math.Floor(pos.X)) Mod 2 <> 0 Then
            diffuse = Color.White
            reflect = 0.1
        End If

        Return New SurfaceProperties With {
            .Specular = Color.White,
            .Diffuse = diffuse,
            .Reflect = reflect,
            .Roughness = 150
        }
    End Function
End Class

Class Surfaces
    Public Shared Shiny As ISurface = New ShinySurface()
    Public Shared CheckerBoard As ISurface = New CheckerboardSurface()
End Class

Class Scene
    Public Camera As Camera
    Public Lights As List(Of Light) = New List(Of Light)
    Public Things As List(Of IThing) = New List(Of IThing)

    Public Sub New()
        Camera = New Camera(New Vector(3.0, 2.0, 4.0), New Vector(-1.0, 0.5, 0.0))

        Things.Add(New Plane(New Vector(0.0, 1.0, 0.0), 0.0, Surfaces.CheckerBoard))
        Things.Add(New Sphere(New Vector(0.0, 1.0, -0.25), 1.0, Surfaces.Shiny))
        Things.Add(New Sphere(New Vector(-1.0, 0.5, 1.5), 0.5, Surfaces.Shiny))

        Lights.Add(New Light(New Vector(-2.0, 2.5, 0.0), New Color(0.49, 0.07, 0.07)))
        Lights.Add(New Light(New Vector(1.5, 2.5, 1.5), New Color(0.07, 0.07, 0.49)))
        Lights.Add(New Light(New Vector(1.5, 2.5, -1.5), New Color(0.07, 0.49, 0.071)))
        Lights.Add(New Light(New Vector(0.0, 3.5, 0.0), New Color(0.21, 0.21, 0.35)))
    End Sub
End Class

Class RayTracerEngine
    Private maxDepth As Integer = 5
    Private Scene As Scene

    Private Function Intersections(ray As Ray) As Intersection
        Dim closest = Double.PositiveInfinity
        Dim closestInter As Intersection = Nothing

        For i = 0 To Scene.Things.Count - 1
            Dim inter = Scene.Things(i).Intersect(ray)
            If (inter IsNot Nothing AndAlso inter.Dist < closest) Then
                closestInter = inter
                closest = inter.Dist
            End If
        Next
        Return closestInter

    End Function

    Private Function TestRay(ray As Ray) As Double
        Dim isect As Intersection = Me.Intersections(ray)
        If (isect IsNot Nothing) Then
            Return isect.Dist
        Else
            Return Double.NaN
        End If
    End Function

    Private Function TraceRay(ray As Ray, depth As Integer) As Color
        Dim isect As Intersection = Me.Intersections(ray)
        If (isect Is Nothing) Then Return Color.Background
        Return Me.Shade(isect, depth)
    End Function

    Private Function Shade(isect As Intersection, depth As Integer) As Color
        Dim d As Vector = isect.Ray.Dir

        Dim pos = (isect.Dist * d) + isect.Ray.Start
        Dim normal = isect.Thing.Normal(pos)
        Dim reflectDir = d - (2 * normal.Dot(d) * normal)
        Dim surface = isect.Thing.Surface.GetSurfaceProperties(pos)

        Dim naturalColor = Color.Background + Me.GetNaturalColor(surface, pos, normal, reflectDir)
        Dim reflectedColor = If(depth >= Me.maxDepth, Color.Grey, Me.GetReflectionColor(surface, pos, normal, reflectDir, depth))

        Return naturalColor + reflectedColor
    End Function

    Private Function GetReflectionColor(surface As SurfaceProperties, pos As Vector, normal As Vector, rd As Vector, depth As Integer) As Color
        Return surface.Reflect * Me.TraceRay(New Ray(pos, rd), depth + 1)
    End Function

    Private Function GetNaturalColor(surface As SurfaceProperties, pos As Vector, norm As Vector, rd As Vector) As Color

        Dim resultColor As Color = Color.DefaultColor

        For i = 0 To Scene.Lights.Count - 1
            Dim light = Scene.Lights(i)
            Dim ldis = light.Pos - pos
            Dim livec = ldis.Norm
            Dim neatIsect = Me.TestRay(New Ray(pos, livec))

            Dim isInShadow = If(Double.IsNaN(neatIsect), False, (neatIsect <= ldis.Length))
            If (Not isInShadow) Then

                Dim illum = livec.Dot(norm)
                Dim lcolor = If((illum > 0), illum * light.Color, Color.DefaultColor)

                Dim specular = livec.Dot(rd.Norm)
                Dim scolor = If(specular > 0, (Math.Pow(specular, surface.Roughness) * light.Color), Color.DefaultColor)

                resultColor = resultColor + (surface.Diffuse * lcolor) + (surface.Specular * scolor)
            End If
        Next
        Return resultColor

    End Function

    Public Sub Render(scene As Scene, bmp As System.Drawing.Bitmap)
        Dim w As Integer = bmp.Width
        Dim h As Integer = bmp.Height
        Me.Scene = scene

        Dim GetPoint = Function(x As Integer, y As Integer, Camera As Camera) As Vector
                           Dim recenterX = (x - (w / 2.0)) / 2.0 / w
                           Dim recenterY = -(y - (h / 2.0)) / 2.0 / h
                           Return (Camera.Forward + (recenterX * Camera.Right) + (recenterY * Camera.Up)).Norm
                       End Function

        Dim bitmapData As Drawing.Imaging.BitmapData = bmp.LockBits(New Drawing.Rectangle(0, 0, w, h), Drawing.Imaging.ImageLockMode.ReadWrite, bmp.PixelFormat)
        Dim stride As Integer = bitmapData.Stride
        Dim rgbData() As Byte
        Dim size As Integer = stride * h
        ReDim rgbData(size)

        System.Runtime.InteropServices.Marshal.Copy(bitmapData.Scan0, rgbData, 0, size)

        Dim ray = New Ray(scene.Camera.Pos, New Vector(0, 0, 0))

        For y = 0 To h - 1
            For x = 0 To w - 1
                ray.Dir = GetPoint(x, y, scene.Camera)
                Dim color = Me.TraceRay(ray, 0).ToDrawingColor()
                Dim pos = y * stride + x * 4
                rgbData(pos + 0) = color.B
                rgbData(pos + 1) = color.G
                rgbData(pos + 2) = color.R
                rgbData(pos + 3) = 255
            Next
        Next

        System.Runtime.InteropServices.Marshal.Copy(rgbData, 0, bitmapData.Scan0, size)
        bmp.UnlockBits(bitmapData)
    End Sub
End Class