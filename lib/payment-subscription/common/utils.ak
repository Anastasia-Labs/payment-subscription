use aiken/primitive/bytearray
use payment_subscription/common/cip68

pub fn convert_ref_tn_to_user(x: ByteArray) -> ByteArray {
  convert_token_name(x, cip68.prefix_length, cip68.prefix_222)
}

pub fn convert_user_tn_to_ref(x: ByteArray) -> ByteArray {
  convert_token_name(x, cip68.prefix_length, cip68.prefix_100)
}

fn convert_token_name(
  x: ByteArray,
  prefix_length: Int,
  prefix_to: ByteArray,
) -> ByteArray {
  bytearray.concat(prefix_to, bytearray.drop(x, prefix_length))
}
