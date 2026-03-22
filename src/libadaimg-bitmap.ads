with Types; use Types;
with Ada.Unchecked_Deallocation;
package Libadaimg.Bitmap is pragma Preelaborate;   
   type Compression_Method is (
      BI_RGB,
      BI_RLE8,
      BI_RLE4,
      BI_BITFIELDS,
      BI_JPEG,
      BI_PNG
   );
   for Compression_Method'Size use 32;

   type Pixel is record
      B,G,R,A : Byte;
   end record with Pack;
   
   type Pixels is array (Natural range <>, Natural range <>) of Pixel with Pack;
   type Pixels_Access is access all Pixels;
   procedure Free_Pixels is new Ada.Unchecked_Deallocation (
      Object => Pixels,
      Name   => Pixels_Access
   );
   --- bitmasks for 16 bit (565); 12 bytes to write
   R16_Mask : constant UInt_32 := 16#F800#;
   G16_Mask : constant UInt_32 := 16#07E0#;
   B16_Mask : constant UInt_32 := 16#001F#;

   -- bitmasks for 32 bit (RGBA);
   R32_Mask : constant UInt_32 := 16#00FF_0000#;
   G32_Mask : constant UInt_32 := 16#0000_FF00#;
   B32_Mask : constant UInt_32 := 16#0000_00FF#;

   type Bitmap_Signature is new Packed_Byte_Array(0..1);
   subtype Color_Depth is Types.UInt_16
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
      Colors_Important : UInt_32;
   end record with Pack;

   type Image is record 
      Header      : Bitmap_Header;
      Info_Header : Dib_Header;
      Pixels      : Pixels_Access;
   end record;
   
   type Image_Access is access all Image;
   procedure Free_Image (Img : in out Image_Access);

   function Create_Image (
      Width  : Int_32;
      Height : Int_32;
      Depth  : Color_Depth;
      Bitfields : Boolean := False
   ) return Image;

   private
      procedure Dealloc is new Ada.Unchecked_Deallocation (
         Object => Image,
         Name   => Image_Access
      );
end Libadaimg.Bitmap;