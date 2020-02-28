require( "pcx-loader");

local fn = "images/example16.pcx"

local image = pcx.Load( fn );

local showPaletteData = true;
local showImageData = true;

if( image ~= nil ) then
    if(showImageData) then
        print(" ### IMAGE DATA ### ");
        for y = 1, image.height do
            local line = string.format("%4i: ", y);
            for x = 1, image.width do
                
                line = string.format("%s %4i", line, image.data[y][x]);
            end
            print( line )
        end
    end
    if(showPaletteData) then
        print(" ### PALETTE DATA ### ");
        local i=0;
        repeat
            local line = "";
            for j=1, 8 do
                line = line .. string.format( "%4i: R%3i G%3i B%3i ", i, image.palette[i].r, image.palette[i].g, image.palette[i].b );
                i=i+1;
            end
            print( line );
        until i>255
    end
end


