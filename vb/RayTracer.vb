Imports System.IO
Imports System.Runtime.InteropServices

Module RayTracer

    Sub Main()
        Dim sw As New Stopwatch()
        Console.WriteLine("VB.Net RayTracer Test")
        sw.Start()
        Dim image As New Image(500, 500)
        Dim scene As New Scene()
        Dim rayTracer As New RayTracerEngine()
        rayTracer.Render(scene, image)
        sw.Stop()
        image.Save("vb-ray.png")
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

Structure RGBColor
    Public B As Byte
    Public G As Byte
    Public R As Byte
    Public A As Byte
End Structure

<StructLayout(LayoutKind.Sequential, Pack:=1)>
Structure BITMAPINFOHEADER
    Public biSize As UInt32
    Public biWidth As Int32
    Public biHeight As Int32
    Public biPlanes As Int16
    Public biBitCount As Int16
    Public biCompression As UInt32
    Public biSizeImage As UInt32
    Public biXPelsPerMeter As Int32
    Public biYPelsPerMeter As Int32
    Public biClrUsed As UInt32
    Public biClrImportant As UInt32
End Structure

<StructLayout(LayoutKind.Sequential, Pack:=1)>
Structure BITMAPFILEHEADER
    Public bfType As UInt16
    Public bfSize As UInt32
    Public bfOffBits As UInt32
    Public bfReserved1 As UInt16
    Public bfReserved2 As UInt16
End Structure

Class Image
    Public ReadOnly Width As Integer
    Public ReadOnly Height As Integer
    Private Data As RGBColor()

    Public Sub New(w As Integer, h As Integer)
        Width = w
        Height = h
        Data = New RGBColor(w * h - 1) {}
    End Sub

    Public Sub SetColor(x As Integer, y As Integer, c As RGBColor)
        Data(y * Height + x) = c
    End Sub

    Public Sub Save(fileName As String)

        Dim infoHeaderSize = Marshal.SizeOf(GetType(BITMAPINFOHEADER))
        Dim fileHeaderSize = Marshal.SizeOf(GetType(BITMAPFILEHEADER))
        Dim offBits = infoHeaderSize + fileHeaderSize

        Dim infoHeader = New BITMAPINFOHEADER With {
            .biSize = CUInt(infoHeaderSize),
            .biBitCount = 32,
            .biClrImportant = 0,
            .biClrUsed = 0,
            .biCompression = 0,
            .biHeight = -Height,
            .biWidth = Width,
            .biPlanes = 1,
            .biSizeImage = CUInt((Width * Height * 4))
        }

        Dim fileHeader = New BITMAPFILEHEADER With {
            .bfType = 66 + (77 << 8),
            .bfOffBits = CUInt(offBits),
            .bfSize = CUInt(offBits + infoHeader.biSizeImage)
        }

        Using writer = New BinaryWriter(System.IO.File.Open(fileName, FileMode.Create))
            writer.Write(GetBytes(fileHeader))
            writer.Write(GetBytes(infoHeader))
            For Each color In Data
                writer.Write(color.B)
                writer.Write(color.G)
                writer.Write(color.R)
                writer.Write(color.A)
            Next
        End Using
    End Sub

    Private Function GetBytes(Of T)(data As T) As Byte()
        Dim length = Marshal.SizeOf(data)
        Dim ptr = Marshal.AllocHGlobal(length)
        Dim result = New Byte(length - 1) {}
        Marshal.StructureToPtr(data, ptr, True)
        Marshal.Copy(ptr, result, 0, length)
        Marshal.FreeHGlobal(ptr)
        Return result
    End Function

End Class

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

    Public Function ToDrawingColor() As RGBColor
        Return New RGBColor With {.R = Clamp(R), .G = Clamp(G), .B = Clamp(B), .A = 255}
    End Function

    Public Shared Function Clamp(c As Double) As Byte
        If (c > 1.0) Then Return 255
        If (c < 0.0) Then Return 0
        Return CByte(c * 255)
    End Function

End Structure

Class Camera
    Public Forward As Vector
    Public Right As Vector
    Public Up As Vector
    Public Pos As Vector

    Public Sub New(position As Vector, lookAt As Vector)
        Dim down = New Vector(0.0, -1.0, 0.0)
        Pos = position
        Forward = (lookAt - position).Norm
        Right = 1.5 * Forward.Cross(down).Norm
        Up = 1.5 * Forward.Cross(Right).Norm
    End Sub

    Function GetPoint(x As Integer, y As Integer, w As Integer, h As Integer) As Vector
        Dim recenterX = (x - (w / 2.0)) / 2.0 / w
        Dim recenterY = -(y - (h / 2.0)) / 2.0 / h
        Return (Me.Forward + (recenterX * Me.Right) + (recenterY * Me.Up)).Norm()
    End Function

End Class

Structure Ray
    Public Start As Vector
    Public Dir As Vector

    Public Sub New(start As Vector, dir As Vector)
        Me.Start = start
        Me.Dir = dir
    End Sub

End Structure

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

    Public Sub New(diffuse As Color, specular As Color, reflect As Double, roughness As Double)
        Me.Diffuse = diffuse
        Me.Specular = specular
        Me.Reflect = reflect
        Me.Roughness = roughness
    End Sub

End Structure

Interface ISurface

    Function GetSurfaceProperties(ByRef pos As Vector) As SurfaceProperties

End Interface

Interface IThing

    Function Intersect(ByRef ray As Ray) As Intersection

    Function Normal(ByRef pos As Vector) As Vector

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

    Private ReadOnly Radius2 As Double
    Private Center As Vector

    Public Sub New(center As Vector, radius As Double, surface As ISurface)
        Me.Radius2 = radius * radius
        Me.Surface = surface
        Me.Center = center
    End Sub

    Public Function Intersect(ByRef ray As Ray) As Intersection Implements IThing.Intersect
        Dim eo = (Me.Center - ray.Start)
        Dim v = eo.Dot(ray.Dir)
        If (v >= 0) Then
            Dim disc = Me.Radius2 - (eo.Dot(eo) - v * v)
            If (disc >= 0) Then
                Dim dist = v - Math.Sqrt(disc)
                Return New Intersection(Me, ray, dist)
            End If
        End If
        Return Nothing
    End Function

    Public Function Normal(ByRef pos As Vector) As Vector Implements IThing.Normal
        Return (pos - Me.Center).Norm
    End Function

    Public Property Surface As ISurface Implements IThing.Surface
End Class

Class Plane
    Implements IThing

    Private Normal As Vector
    Private ReadOnly Offset As Double

    Public Sub New(normal As Vector, offset As Double, surface As ISurface)
        Me.Normal = normal
        Me.Offset = offset
        Me.Surface = surface
    End Sub

    Public Function Intersect(ByRef ray As Ray) As Intersection Implements IThing.Intersect
        Dim denom = Me.Normal.Dot(ray.Dir)
        If (denom <= 0) Then
            Dim dist = (Me.Normal.Dot(ray.Start) + Me.Offset) / (-denom)
            Return New Intersection(Me, ray, dist)
        End If
        Return Nothing
    End Function

    Public Function GetNormal(ByRef pos As Vector) As Vector Implements IThing.Normal
        Return Me.Normal
    End Function

    Public Property Surface As ISurface Implements IThing.Surface
End Class

Class ShinySurface
    Implements ISurface

    Public Function GetSurfaceProperties(ByRef pos As Vector) As SurfaceProperties Implements ISurface.GetSurfaceProperties
        Return New SurfaceProperties(Color.White, Color.Grey, 0.7, 250)
    End Function

End Class

Class CheckerboardSurface
    Implements ISurface

    Public Function GetSurfaceProperties(ByRef pos As Vector) As SurfaceProperties Implements ISurface.GetSurfaceProperties
        Dim condition = (Math.Floor(pos.Z) + Math.Floor(pos.X)) Mod 2 <> 0

        If condition Then
            Return New SurfaceProperties(Color.White, Color.White, 0.1, 150)
        End If

        Return New SurfaceProperties(Color.Black, Color.White, 0.7, 150)
    End Function

End Class

Class Scene
    Public Camera As Camera
    Public Lights As List(Of Light) = New List(Of Light)
    Public Things As List(Of IThing) = New List(Of IThing)

    Public Sub New()

        Dim Shiny As ISurface = New ShinySurface()
        Dim CheckerBoard As ISurface = New CheckerboardSurface()

        Camera = New Camera(New Vector(3.0, 2.0, 4.0), New Vector(-1.0, 0.5, 0.0))

        Things.Add(New Plane(New Vector(0.0, 1.0, 0.0), 0.0, CheckerBoard))
        Things.Add(New Sphere(New Vector(0.0, 1.0, -0.25), 1.0, Shiny))
        Things.Add(New Sphere(New Vector(-1.0, 0.5, 1.5), 0.5, Shiny))

        Lights.Add(New Light(New Vector(-2.0, 2.5, 0.0), New Color(0.49, 0.07, 0.07)))
        Lights.Add(New Light(New Vector(1.5, 2.5, 1.5), New Color(0.07, 0.07, 0.49)))
        Lights.Add(New Light(New Vector(1.5, 2.5, -1.5), New Color(0.07, 0.49, 0.071)))
        Lights.Add(New Light(New Vector(0.0, 3.5, 0.0), New Color(0.21, 0.21, 0.35)))
    End Sub

End Class

Class RayTracerEngine
    Private ReadOnly MaxDepth As Integer = 5
    Private Scene As Scene

    Private Function Intersections(ByRef ray As Ray) As Intersection
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

    Private Function TraceRay(ByRef ray As Ray, depth As Integer) As Color
        Dim isect As Intersection = Me.Intersections(ray)
        If (isect Is Nothing) Then
            Return Color.Background
        End If
        Return Me.Shade(isect, depth)
    End Function

    Private Function Shade(isect As Intersection, depth As Integer) As Color
        Dim d As Vector = isect.Ray.Dir

        Dim pos = (isect.Dist * d) + isect.Ray.Start
        Dim normal = isect.Thing.Normal(pos)
        Dim reflectDir = d - (2 * normal.Dot(d) * normal)
        Dim surface = isect.Thing.Surface.GetSurfaceProperties(pos)

        Dim naturalColor = Color.Background + Me.GetNaturalColor(surface, pos, normal, reflectDir)
        Dim reflectedColor = If(depth >= Me.MaxDepth, Color.Grey, Me.GetReflectionColor(surface, pos, reflectDir, depth))

        Return naturalColor + reflectedColor
    End Function

    Private Function GetReflectionColor(surface As SurfaceProperties, pos As Vector, rd As Vector, depth As Integer) As Color
        Return surface.Reflect * Me.TraceRay(New Ray(pos, rd), depth + 1)
    End Function

    Private Function GetNaturalColor(surface As SurfaceProperties, pos As Vector, norm As Vector, rd As Vector) As Color
        Dim resultColor As Color = Color.DefaultColor
        Dim reflectDir = rd.Norm

        For i = 0 To Scene.Lights.Count - 1
            Dim light = Scene.Lights(i)
            Dim ldis = light.Pos - pos
            Dim livec = ldis.Norm()
            Dim neatIsect = Me.Intersections(New Ray(pos, livec))
            Dim isInShadow = If(neatIsect IsNot Nothing, (neatIsect.Dist <= ldis.Length), False)

            If (Not isInShadow) Then
                Dim illum = livec.Dot(norm)
                Dim specular = livec.Dot(reflectDir)

                Dim lcolor = If((illum > 0), illum * light.Color, Color.DefaultColor)
                Dim scolor = If(specular > 0, (Math.Pow(specular, surface.Roughness) * light.Color), Color.DefaultColor)

                resultColor = resultColor + (surface.Diffuse * lcolor) + (surface.Specular * scolor)
            End If
        Next
        Return resultColor
    End Function

    Public Sub Render(scene As Scene, image As Image)
        Me.Scene = scene

        Dim w As Integer = image.Width
        Dim h As Integer = image.Height

        For y = 0 To h - 1
            For x = 0 To w - 1
                Dim point = scene.Camera.GetPoint(x, y, w, h)
                Dim ray = New Ray(scene.Camera.Pos, point)
                Dim color = TraceRay(ray, 0).ToDrawingColor()
                image.SetColor(x, y, color)
            Next
        Next
    End Sub

End Class