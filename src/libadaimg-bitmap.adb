with Libadaimg.Bitmap.Palettes; 
with Interfaces; use Interfaces;
package body Libadaimg.Bitmap is  
   function Create_Image (
      Width     : Int_32; 
      Height    : Int_32; 
      Depth     : Color_Depth; 
      Bitfields : Boolean := False
   ) return Image is
      Using_Bitfields : constant Boolean := Bitfields and Depth in 16 | 32;
      Row_Stride      : constant UInt_32 := ((UInt_32(Depth) * UInt_32(Width) + 31) / 32) * 4;
      Image_Size      : constant UInt_32 := Row_Stride * UInt_32(abs(Height));
      Palette_Size    : constant Int_32  := (if Depth in 1..8 then (2 ** Natural(Depth)) * 4 
                                             elsif Using_Bitfields then 12 else 0);
   begin
      return Result : Image do
         Result.Row_Stride := Row_Stride;
         Result.Info_Header := (
            Img_Width   => Width, Img_Height => Height, Depth => Depth,
            Compression => (if Using_Bitfields then BI_BITFIELDS else BI_RGB),
            Image_Size  => Image_Size, Planes => 1,
            H_Res       => 0,
            V_Res       => 0,
            Colors_Used => (if Depth in 1 | 4 | 8 then 2 ** Natural(Depth) else 0),
            others      => <>
         );
         Result.File_Header := (
            Signature => (Character'Pos('B'), Character'Pos('M')),
            Offset    => 14 + 40 + UInt_32(Palette_Size),
            File_Size => 14 + 40 + UInt_32(Palette_Size) + Image_Size,
            others    => <>
         );
         Result.Pixels := new Pixels (1 .. Natural(Image_Size));
         Result.Pixels.all := (others => 0);
      end return;
   end Create_Image;

   procedure Write_Image (Stream : in out Ada.Streams.Stream_IO.Stream_Access; Img : Image) is
      use Palettes;
      use Ada.Streams;
      use Ada.Streams.Stream_IO;
      Row_Size : constant UInt_32 := 
         ((UInt_32(Img.Info_Header.Depth) * UInt_32(Img.Info_Header.Img_Width) + 31) / 32) * 4;
      Data_Width : constant UInt_32 := 
         (UInt_32(Img.Info_Header.Depth) * UInt_32(Img.Info_Header.Img_Width) + 7) / 8;
      Padding_Count : constant UInt_32 := Row_Size - Data_Width;
      Zero_Padding  : constant Stream_Element_Array (1 .. Stream_Element_Offset(Padding_Count)) := (others => 0);
   begin
      Bitmap_Header'Write (Stream, Img.File_Header);
      Dib_Header'Write (Stream, Img.Info_Header);
      if Img.Info_Header.Depth in Depths_With_Palette then
         if Img.Palette /= null then
            declare
               Entries : constant Natural := 2 ** Natural(Img.Info_Header.Depth);
               Sub_Palette : constant Color_Table := 
                  Img.Palette(Img.Palette'First .. Img.Palette'First + Entries - 1);
            begin
               Color_Table'Write (Stream, Sub_Palette);
            end;
         end if;
      elsif Img.Info_Header.Compression = BI_BITFIELDS then
         if Img.Info_Header.Depth = 16 then
            UInt_32'Write (Stream, R16_Mask);
            UInt_32'Write (Stream, G16_Mask);
            UInt_32'Write (Stream, B16_Mask);
         else 
            UInt_32'Write (Stream, R32_Mask);
            UInt_32'Write (Stream, G32_Mask);
            UInt_32'Write (Stream, B32_Mask);
         end if;
      end if;
      Pixels'Write (Stream, Img.Pixels.all);
   end Write_Image;

   procedure Set_Pixel (Img : in out Image; X, Y : Natural; Color : BGRA_Pixel) is
      Row_Start : constant Natural := Y * Natural(Img.Row_Stride);
      Depth     : constant Color_Depth := Img.Info_Header.Depth;
      Pos       : Natural;
   begin
      case Depth is
         when 32 =>
            declare
               Target : BGRA_Pixel;
               for Target'Address use Img.Pixels(Row_Start + (X * 4) + 1)'Address;
            begin
               Target := Color;
            end;
         when 24 =>
            Pos := Row_Start + (X * 3) + 1;
            Img.Pixels(Pos)     := Color.B;
            Img.Pixels(Pos + 1) := Color.G;
            Img.Pixels(Pos + 2) := Color.R;
         when 16 =>
            Pos := Row_Start + (X * 2) + 1;
            declare
               -- 5 red, 6 green, 5 blue 
               Word : UInt_16 := 0;
            begin
               Word := Shift_Left (UInt_16(Color.R and 16#F8#), 8) or
                       Shift_Left (UInt_16(Color.G and 16#FC#), 3) or
                       Shift_Right(UInt_16(Color.B and 16#F8#), 3);
               Img.Pixels(Pos)     := Byte(Word and 16#FF#);
               Img.Pixels(Pos + 1) := Byte(Shift_Right(Word, 8));
            end;
         when 1 | 4 | 8 =>
            declare
               Idx : constant Byte := Find_Nearest_Match(Img, Color);
            begin
               Set_Pixel_Index (Img, X, Y, Idx);
            end;
      end case;
   end Set_Pixel;

   procedure Set_Pixel_Index (Img : in out Image; X, Y  : Natural; Index : Byte) is
      Row_Start : constant Natural := Y * Natural(Img.Row_Stride);
      Depth     : constant Color_Depth := Img.Info_Header.Depth;
   begin
      case Depth is
         when 8 =>
            Img.Pixels(Row_Start + X + 1) := Index;
         when 4 =>
            declare
               Byte_Pos : constant Natural := Row_Start + (X / 2) + 1;
               Old_Byte : constant Byte    := Img.Pixels(Byte_Pos);
               Val      : constant Byte    := Index and 16#0F#;
            begin
               if X mod 2 = 0 then
                  Img.Pixels(Byte_Pos) := (Old_Byte and 16#0F#) or Shift_Left(Val, 4);
               else
                  Img.Pixels(Byte_Pos) := (Old_Byte and 16#F0#) or Val;
               end if;
            end;

         when 1 =>
            declare
               Byte_Pos : constant Natural := Row_Start + (X / 8) + 1;
               Bit_Idx  : constant Natural := 7 - (X mod 8);
               Old_Byte : constant Byte    := Img.Pixels(Byte_Pos);
            begin
               if (Index and 1) /= 0 then
                  Img.Pixels(Byte_Pos) := Old_Byte or Shift_Left(1, Bit_Idx);
               else
                  Img.Pixels(Byte_Pos) := Old_Byte and not Shift_Left(1, Bit_Idx);
               end if;
            end;
         when others =>
            null;
      end case;
   end Set_Pixel_Index;

   procedure Save_Image (Img : Image; Out_Path : String) is 
      use Ada.Streams.Stream_IO;
      File  : File_Type;
      Strm  : Stream_Access := null;
   begin 
      Create (File, Mode => Out_File, Name => Out_Path);
      Strm := Stream (File);
      Write_Image (Strm, Img); 
      Close (File);
   end Save_Image;

   function Color_Distance (A, B : BGRA_Pixel) return Long_Integer is
      dR : constant Long_Integer := Long_Integer(A.R) - Long_Integer(B.R);
      dG : constant Long_Integer := Long_Integer(A.G) - Long_Integer(B.G);
      dB : constant Long_Integer := Long_Integer(A.B) - Long_Integer(B.B);
   begin
      return (dR * dR) + (dG * dG) + (dB * dB);
   end Color_Distance;

   function Find_Nearest_Match (Img : Image; Color : BGRA_Pixel) return Byte is
      Best_Dist  : Long_Integer := Long_Integer'Last;
      Best_Index : Byte := 0;
      Dist    : Long_Integer;
      Entries : constant Natural := 2 ** Natural(Img.Info_Header.Depth);
   begin
      if Img.Palette = null then
         return 0;
      end if;
      for I in 0 .. Entries - 1 loop
         Dist := Color_Distance (Img.Palette(Img.Palette'First + I), Color);
         if Dist < Best_Dist then
            Best_Dist  := Dist;
            Best_Index := Byte(I);
            exit when Best_Dist = 0;
         end if;
      end loop;
      return Best_Index;
   end Find_Nearest_Match;

   procedure Free_Image (Img : in out Image_Access) is 
   begin 
      if Img.Pixels /= null then
         Free_Pixels (Img.Pixels);
      end if;
      Dealloc_Image (Img);
   end Free_Image;

   function As_Rgba (Pixel : BGRA_Pixel) return RGBA_Pixel is 
      Result : RGBA_Pixel;
      for Result'Address use Pixel'Address;
   begin
      return Result;
   end As_Rgba;
end Libadaimg.Bitmap;