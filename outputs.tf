output "key_pair" {
  description = "Key Pair Material"
  value = module.key_pair.key_pair_fingerprint
}
