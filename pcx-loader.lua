--[[
Lua script for reading PCX files
that have indexed 256 color palette

FILE FORMAT SOURCES
https://www.fileformat.info/format/pcx/egff.htm
https://en.wikipedia.org/wiki/PCX
--]]

pcx = {}

    --BITSHIFTING operations (so that this code works with pure lua 5.1.5 without need of any C)
    --https://stackoverflow.com/a/6026257
    local function lshift(x, by)
        return x * 2 ^ by
    end

    local function rshift(x, by) 
        return math.floor(x / 2 ^ by)
    end
    --
    local function cbf( x, bit )  --check bitflag --check state of bit, returns true or false
        local retVal = nil;
        if( bit > 0 ) then
            x = rshift(x,bit-1)
            if( x % 2 == 1 ) then
                retVal = true;
            else
                retVal = false;
            end 
        end
        return retVal;
    end

    --END OF BITSHIFT


    local function byteDec( byte )
        return tonumber( string.byte(byte));
    end

    function byteSum( byteL, byteM )    -- WORD
        return byteDec( byteL) +  byteDec( byteM ) * 2^8;
    end


    -------------------------------

    function pcx.ReadHeader( pcx_file, pcx_headerSize )
        local header = {};

        if( pcx_headerSize == nil ) then
            pcx_headerSize = 128;
        end
        
        assert( pcx_file:seek("set", 0) ); -- setHeader to 0
        for i=1, pcx_headerSize do
            header[#header+1] =  pcx_file:read(1);
        end

        return header
    end
    
    local function CloseFile( pcxfile )
        io.close( pcxfile );
    end

    local function Clean( pcxfile)
        -- cleaning up?
        --pcx_image_raw = {};
        --header = {};
        CloseFile( pcxfile );
    end

    local function OpenFile( filename ) 
        return assert( io.open( filename, "rb" ));
    end

    function pcx.Load( filename, showConsole ) 
        
        --START 
        if( showConsole == nil ) then
            showConsole = false;
        end

        local retVal = {};
        local header = {};
        local headerSize = 128; -- Header size is always same
        local paletteSize = 769; -- 3x256+1 --palette starts with identification of 0x0C

        local file = OpenFile( filename, headerSize );
        local fileSize = file:seek("end");
        local headerBytes = pcx.ReadHeader( file );     --there is no check that fileSize is enough to read header.
        print( "file size: " .. fileSize)
        CloseFile( file );

        -- DEBUG: output header
        -- for k, v in pairs( header ) do
        --     print( string.format("%2i: %s", k, string.byte(v)))
        -- end


        -- PROCESSING HEADER
        header.identifier = byteDec( headerBytes[1] );
        header.version = byteDec( headerBytes[2] )
        header.encoding = byteDec( headerBytes[3] );
        header.bitsPerPixel = byteDec( headerBytes[4]);
        header.cx_min = byteSum( headerBytes[5], headerBytes[6]);
        header.cy_min = byteSum( headerBytes[7], headerBytes[8]);
        header.cx_max = byteSum( headerBytes[9], headerBytes[10] );
        header.cy_max = byteSum( headerBytes[11], headerBytes[12]); --tonumber( string.byte(header[12]) )*2^8 + tonumber( string.byte(header[11])+1 )
        header.resDPIh = byteSum( headerBytes[13], headerBytes[14]); --not used
        header.resDPIv = byteSum( headerBytes[15], headerBytes[16]); --not used
        --EGA PALETTE (48 BYTES)
        --RESERVED1 (1 BYTE)
        header.numBitPlanes = byteDec( headerBytes[66] );
        header.bytesPerScanline = byteSum( headerBytes[67], headerBytes[68] );
        header.paletteType = byteSum( headerBytes[69], headerBytes[70] );

        header.screenSizeH = byteSum( headerBytes[71], headerBytes[72] );  --not used
        header.screenSizeV = byteSum( headerBytes[73], headerBytes[74] );  --not used
        --RESERVED2 (54 BYTES)

        --
        --bytesPerScanline should "match" with bitPlanes*header.bitsPerPixel

        local pcx_width = header.cx_max - header.cx_min + 1;
        local pcx_height = header.cy_max - header.cy_min + 1;

        local scanlineLength = header.numBitPlanes * header.bytesPerScanline; --This is needed! After testing found out that relying blindly to width could cause problems because of programs could add additional bytes.
        local linePaddingSize = ((header.bytesPerScanline * header.numBitPlanes) * (8/header.bitsPerPixel)) - ((header.cx_max - header.cx_min) +1 );

        -- IMAGE INFORMATION
        print( "Image V:" .. header.version .. " Encoding: " .. header.encoding )
        print( "Image size: " .. pcx_width .. " x ".. pcx_height )
        print( "bPP:" .. header.bitsPerPixel .. " bitPlanes: ".. header.numBitPlanes .. " BpScanline " .. header.bytesPerScanline .. " paletteType:" .. header.paletteType);

        print( "SL:" .. scanlineLength .. " linePSize: " .. linePaddingSize );

        --for our case
        --bitPlanes needs to be 1
        --bitsPerPixel needs to be 8

        -- local pcx_data_count = scanlineLength * pcx_height; --scanlineLength * height; 
        -- local pcx_image_data_size = fileSize -headerSize -paletteSize;
        
        if( header.identifier ==  10 and header.numBitPlanes == 1 and header.bitsPerPixel == 8 ) then
            -- REOPENING FILE
            file = OpenFile( filename, headerSize );
            file:seek("set", 128 )
            
            local pcx_image_raw = {}; -- pcx_image_raw[1] = {}
            local pcx_current_pixel = 0; --for whole image data count!
            local pcx_line = 1;

            local paletteData = {};

            while( pcx_line <= pcx_height ) do
                local pos = 1;
                pcx_image_raw[pcx_line] = {};
                while( pos <= scanlineLength ) do
                    local byte_current = byteDec( file:read(1) );

                    local function addData()
                        if( pos <= pcx_width ) then
                            pcx_image_raw[pcx_line][pos] = byte_current;
                        end
                        pcx_current_pixel = pcx_current_pixel + 1;
                        pos = pos + 1;
                    end

                    if( cbf( byte_current, 8) and cbf(byte_current, 7)) then
                        local byte_repeat = byte_current - 192; -- 0xC0

                        byte_current = byteDec( file:read(1) );
                        
                        for i=1, byte_repeat do
                            addData();
                        end
                    else
                        addData();
                    end
                end
                pcx_line = pcx_line + 1;
            end

            --READING PALETTE
            if( file:seek() == fileSize -paletteSize ) then     --SKIP palette reading if position after reading image data is not matching
                local tt = byteDec( file:read(1) );
                if( tt == 0x0C ) then   --0x0C (not 0xC0)
                    print("Processing palette data..")
                    for i=0, 255 do
                        paletteData[i] = {};
                        paletteData[i].r = byteDec( file:read(1));
                        paletteData[i].g = byteDec( file:read(1));
                        paletteData[i].b = byteDec( file:read(1));
                    end
                else
                    print("No palette data")
                end
            else
                print("Palette and image data location isn't matching!")
            end
            
            --PRINTING COLORDATA TO CONSOLE
            if( showConsole ) then
                for l, u in pairs( pcx_image_raw ) do
                    local ol = ""
                    for k, v in pairs( pcx_image_raw[l] ) do
                        ol = string.format("%s %3i", ol, v);
                    end
                    print( l .. ":"  .. ol );
                end
            end
            retVal = { 
                header = header,
                data = pcx_image_raw,
                palette = paletteData,
                width = pcx_width, 
                height = pcx_height
            };

            Clean( file );
        else
            print("NOT SUPPORTED FILE!");
            retVal = nil;
        end
        
        return retVal;
    end

return pcx;