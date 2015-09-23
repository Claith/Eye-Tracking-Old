function [ Truth ] = MinMaxLab( Color, MinLab, MaxLab )
%MINMAXLAB Returns 1 if Color within range
%   Returns 1 if Color is greater than MinLab and less than MaxLab; 0 is
%   false, any other number is true

Truth = 0;

%don't trust MATLAB to have short circuiting
if Color(1) >= MinLab(1)
    if Color(1) <= MaxLab(1)
        if Color(2) >= MinLab(2)
            if Color(2) <= MaxLab(2)
                if Color(3) >= MinLab(3)
                    if Color(3) <= MaxLab(3)
                        Truth = 1;
                    end
                end
            end
        end
    end
end

end

