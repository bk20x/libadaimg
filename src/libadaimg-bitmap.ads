with Types; use Types;
with Ada.Unchecked_Deallocation;
with Ada.Streams.Stream_IO;
package Libadaimg.Bitmap is
   type Compression_Method is (
      BI_RGB,
      BI_RLE8,
      BI_RLE4,
      BI_BITFIELDS,
      BI_JPEG,
      BI_PNG
   );
   for Compression_Method'Size use 32;

   type BGRA_Pixel is record 
      B,G,R,A : Byte; 
   end record with Pack;

   type Pixels is new Packed_Byte_Array;
   type Pixels_Access is access all Pixels;
   procedure Free_Pixels is new Ada.Unchecked_Deallocation (
      Object => Pixels,
      Name   => Pixels_Access
   );

   type Color_Table is array (Natural range <>) of aliased BGRA_Pixel with Pack;
   type Color_Table_Access is access constant Color_Table;

   --- bitmasks for 16 bit (565); 12 bytes to write
   R16_Mask : constant UInt_32 := 16#F800#;
   G16_Mask : constant UInt_32 := 16#07E0#;
   B16_Mask : constant UInt_32 := 16#001F#;

   -- bitmasks for 32 bit (RGBA);
   R32_Mask : constant UInt_32 := 16#00FF_0000#;
   G32_Mask : constant UInt_32 := 16#0000_FF00#;
   B32_Mask : constant UInt_32 := 16#0000_00FF#;

   type Bitmap_Signature is new Packed_Byte_Array(0..1);
   subtype Color_Depth is UInt_16
     with Static_Predicate => Color_Depth in 1 | 4 | 8 | 16 | 24 | 32;
     
   type Bitmap_Header is record
      Signature : Bitmap_Signature;
      File_Size : UInt_32;
      Reserved_1: UInt_16 := 0;
      Reserved_2: UInt_16 := 0;
      Offset    : UInt_32;
   end record with Pack;
   
   type Dib_Header is record
      Header_Size : UInt_32 := 40;
      Img_Width   : Int_32; -- in pixels
      Img_Height  : Int_32;
      Planes      : UInt_16 := 1;
      Depth       : Color_Depth; --- bits per pixel
      Compression : Compression_Method;
      Image_Size  : UInt_32; 
      H_Res, V_Res: Int_32;
      Colors_Used : UInt_32;
      Colors_Important : UInt_32 := 0;
   end record with Pack;

   type Image is record 
      File_Header : Bitmap_Header;
      Info_Header : Dib_Header;
      Row_Stride  : UInt_32;
      Pixels      : Pixels_Access;
      Palette     : Color_Table_Access;
   end record;
   
   type Image_Access is access all Image;
   procedure Free_Image (Img : in out Image_Access);

   function Create_Image (
      Width  : Int_32;
      Height : Int_32;
      Depth  : Color_Depth;
      Bitfields : Boolean := False
   ) return Image;
   procedure Set_Pixel (
      Img   : in out Image;
      X,Y   : Natural; 
      Color : BGRA_Pixel
   );
   procedure Save_Image  (Img : Image; Out_Path : String);
   procedure Write_Image (Stream : in out Ada.Streams.Stream_IO.Stream_Access; Img : in Image);
   

   type RGBA_Pixel is record
      R,G,B,A : Byte;
   end record with Pack;
   function As_Rgba (Pixel : BGRA_Pixel) return RGBA_Pixel;
   
   private
      function Color_Distance (A, B : BGRA_Pixel) return Long_Integer;
      function Find_Nearest_Match (Img : Image; Color : BGRA_Pixel) return Byte;
      procedure Set_Pixel_Index (Img : in out Image; X,Y : Natural; Index : Byte);
      procedure Dealloc_Image is new Ada.Unchecked_Deallocation (
         Object => Image,
         Name   => Image_Access
      );
end Libadaimg.Bitmap;