function [i, r]=jmod(val,factor)% Returns frac and int part of real val/factor.% eg jmod(pi,1)n=val/factor;i=floor(n);r=n-i;