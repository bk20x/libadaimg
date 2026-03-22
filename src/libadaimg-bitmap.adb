with Interfaces; use Interfaces;
package body Libadaimg.Bitmap is  
   function Create_Image (
      Width     : Int_32; 
      Height    : Int_32; 
      Depth     : Color_Depth; 
      Bitfields : Boolean := False
   ) return Image is 
      File_Header : Bitmap_Header;
      Info_Header : Dib_Header;
      Using_Bitfields : constant Boolean := Bitfields and Depth in 16 | 32;
      Row_Size_Bytes  : constant UInt_32 := ((UInt_32(Depth) * UInt_32(Width) + 31) / 32) * 4;
      Image_Size      : constant UInt_32 := Row_Size_Bytes * UInt_32(abs(Height));
      Palette_Size    : constant Int_32  := (if Depth in 1..8 then (2 ** Natural(Depth)) * 4 
                                             elsif Using_Bitfields then 12 else 0);
   begin
      Info_Header := (
         Img_Width   => Width,
         Img_Height  => Height,
         Depth       => Depth,
         Compression => (if Using_Bitfields then BI_BITFIELDS else BI_RGB),
         Image_Size  => Image_Size,
         others      => <>
      );      
      File_Header.Signature := (Character'Pos('B'), Character'Pos('M'));
      File_Header.Offset    := Info_Header.Header_Size + UInt_32(Palette_Size) + 14;
      File_Header.File_Size := File_Header.Offset + Info_Header.Image_Size;
      return Result : Image do
         Result.Header := File_Header;
         Result.Info_Header := Info_Header;
         Result.Pixels := 
            new Pixels (1 .. Natural(Height),
                        1 .. Natural(Width));
      end return;      
   end Create_Image;

   procedure Free_Image (Img : in out Image_Access) is 
   begin 
      if Img.Pixels /= null then
         Free_Pixels (Img.Pixels);
      end if;
      Dealloc (Img);
   end Free_Image;

   function As_Rgba (Pixel : BGRA_Pixel) return RGBA_Pixel is 
      Result : RGBA_Pixel;
      for Result'Address use Pixel'Address;
   begin
      return Result;
   end As_Rgba;
end Libadaimg.Bitmap;