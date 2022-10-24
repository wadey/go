//go:build boringcrypto && linux && (amd64 || arm64) && !android && !cmd_go_bootstrap && !msan

package boring

import "crypto/cipher"

func (c *aesCipher) NewGCMTLS() (cipher.AEAD, error) {
	return NewGCMTLS(c)
}
