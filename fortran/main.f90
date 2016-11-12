module ModVector
    implicit none
    
    real(8), parameter :: INF = 1000000.0d+0

    type Vector
        real(8) :: v(3)
    end type
 
    interface assignment (=)
        module procedure vector_assign_scalar
        module procedure vector_assign_vector
    end interface
    
    ! interface operator (+)
    !     module procedure vector_add
    ! end interface    

    ! interface operator (-)
    !     module procedure vector_sub
    ! end interface 
    
    ! interface operator (*)
    !     module procedure vector_mul
    ! end interface         
    
    ! interface operator (.dot.)
    !     module procedure vector_dot
    ! end interface
    
    ! interface operator (.cross.)
    !     module procedure vector_cross
    ! end interface    

contains  
    ! Operators
    subroutine vector_assign_scalar(vec, value)
        implicit none
        type(Vector), intent(out) :: vec
        real(8),      intent(in)  :: value
        vec%v = [value, value, value]
    end subroutine   

    ! subroutine vector_assign_vector(vec, value)
    !     implicit none
    !     type(Vector), intent(out) :: vec
    !     real(8),      intent(in)  :: value(3)
    !     vec%v = value
    ! end subroutine      
    
    ! function vector_dot(a, b)  result(c)
    !     implicit none
    !     type(Vector), intent(in)  :: a, b
    !     type(Vector), intent(out) :: c
        
    !     c%v = dot_product(a%v,b%v)
    ! end function     
    
    ! function vector_cross(a, b)  result(c)
    !     implicit none
    !     type(Vector), intent(in)  :: a, b
    !     type(Vector), intent(out) :: c
        
    !     c%v(1) =  a%v(2) * c%v(3) - a%v(3) * b%v(2)
    !     c%v(2) =  a%v(3) * c%v(1) - a%v(1) * b%v(3)
    !     c%v(3) =  a%v(1) * c%v(2) - a%v(2) * b%v(1)
    ! end function    
    
    ! function vector_add(a, b)  result(c)
    !     implicit none
    !     type(Vector), intent(in)  :: a, b
    !     type(Vector), intent(inout) :: c
        
    !     c%v = a%v + b%v;
    ! end function 
    
    ! function vector_sub(a, b)  result(c)
    !     implicit none
    !     type(Vector), intent(in)  :: a, b
    !     type(Vector), intent(inout) :: c
        
    !     c%v = a%v - b%v;
    ! end function 
    
    ! function vector_mul(a, k)  result(c)
    !     implicit none
    !     type(Vector), intent(in) :: a
    !     type(Vector), intent(inout) :: c
    !     real(8), intent(in) :: k
        
    !     c%v = a%v * k;
    ! end function                 
    
    ! Functions
    pure function Length(vec) result(value)
        type(Vector), intent(in) :: vec
        real(8) :: value
        value = sqrt(sum(vec%v ** 2))         
    end function
    
    pure function Norm(vec) result(value)
        type(Vector), intent(in)  :: vec
        type(Vector), intent(inout) :: value
        real(8) :: mag, div
        
        mag   = Length(vec)
        
        if(mag == 0.0) then
            div = INF
        else
            div = 1.0d+0 / mag
        endif
        
        value%v = vec%v / div
    end function
end module


program hello
    use ModVector

    implicit none
    
    type(Vector) :: a, b, c
    
    a = [2.0d+0, 2.0d+0, 2.0d+0]
    b = [2.0d+0, 2.0d+0, 2.0d+0]
    
    c = a .cross. b
    
    print *, c%v
    ! b = 0;
    ! c = 0;
    
    ! print *, a
    ! print *, b
    ! print *, c    
end program