with Interfaces;
package Types is pragma Pure;
   subtype Byte is Interfaces.Unsigned_8;
   type Byte_Array is array (Natural range <>) of Byte;
   type Packed_Byte_Array is new Byte_Array with Pack;
   subtype UInt_32 is Interfaces.Unsigned_32;
   subtype UInt_16 is Interfaces.Unsigned_16;
   subtype Int_32  is Interfaces.Integer_32;
end Types;