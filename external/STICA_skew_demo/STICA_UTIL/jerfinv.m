function z=jerfinv(p);% Given an area p, return the corresponding z value.% This has been corrected by JP so that it corresponds to% actual erfinv!z = erfinv(2*p-1);z = z*sqrt(2);