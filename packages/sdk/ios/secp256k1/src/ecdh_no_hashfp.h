//
//  ecdh_no_hashfp.h
//  
//
//  Created by Alexander Cyon on 2022-01-31.
//

#ifndef ecdh_no_hashfp_h
#define ecdh_no_hashfp_h

#include "secp256k1_ecdh.h"

int ecdh_skip_hash_extract_x_and_y(unsigned char *output, const unsigned char *x32, const unsigned char *y32, void *data);

const secp256k1_ecdh_hash_function ecdh_skip_hash_extract_x_and_y_fp = ecdh_skip_hash_extract_x_and_y;

#endif /* ecdh_no_hashfp_h */
