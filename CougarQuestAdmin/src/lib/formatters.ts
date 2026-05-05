/**
 * Format a phone number as `+1 (XXX) XXX-XXXX`.
 *
 * Accepts any input — strips non-digits, drops a leading 1 if present, and
 * pads/short-circuits gracefully for partial numbers so it works on input
 * fields and on display.
 *
 * Examples:
 *   '7192136213'        → '+1 (719) 213-6213'
 *   '17192136213'       → '+1 (719) 213-6213'
 *   '+1 (719) 213-6213' → '+1 (719) 213-6213'
 *   '7192'              → '+1 (719) 2'
 *   ''                  → ''
 */
export function formatPhoneNumber(value: string | undefined | null): string {
  if (!value) return ''
  let digits = String(value).replace(/\D/g, '')
  if (digits.length === 11 && digits.startsWith('1')) digits = digits.slice(1)
  if (digits.length === 0) return ''
  if (digits.length <= 3) return `+1 (${digits}`
  if (digits.length <= 6) return `+1 (${digits.slice(0, 3)}) ${digits.slice(3)}`
  return `+1 (${digits.slice(0, 3)}) ${digits.slice(3, 6)}-${digits.slice(6, 10)}`
}

/** Strip a phone-display string back down to digits for storage. */
export function rawDigits(value: string | undefined | null): string {
  if (!value) return ''
  return String(value).replace(/\D/g, '')
}
