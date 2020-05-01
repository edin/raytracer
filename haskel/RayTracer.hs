// TODO: Write haskel code 😂😂😂

data Shape = Plane (Point V3 Double) (V3 Double)
           | Sphere (Point V3 Double) Double

data Ray = Ray { 
    rayOrigin :: Point V3 Double, 
    rayDirection :: V3 Double
}