module ui2

import math

// Pure validation helpers for forms. They check text values against rules
// and return messages, which an application stores and passes back as each
// field's `error`. Nothing here keeps state or reads controls.

pub enum FormCheck {
	required     // Not empty or blank.
	min_length   // At least `length` characters.
	max_length   // At most `length` characters.
	email        // Shaped like an email address; see form_email_valid.
	digits       // Only the digits 0 to 9.
	alphanumeric // Only ASCII letters and digits.
	number       // A number (number_input_parse), within `min` and `max` when set.
	pattern      // Matches `pattern`; see form_pattern_matches.
	equals       // The same as `other`, as a password and its confirmation.
}

// FormRule is one check. Lengths count Unicode characters. Every check but
// required passes an empty value, so an optional field is only checked once
// something is typed into it; add required to make it mandatory.
pub struct FormRule {
pub:
	check   FormCheck
	length  int
	min     ?f64
	max     ?f64
	pattern string
	other   string
	message string // Replaces the default message.
}

// with_message returns the rule with a message of the application's own.
pub fn (rule FormRule) with_message(message string) FormRule {
	return FormRule{
		...rule
		message: message
	}
}

pub fn form_required() FormRule {
	return FormRule{
		check: .required
	}
}

pub fn form_min_length(length int) FormRule {
	return FormRule{
		check:  .min_length
		length: length
	}
}

pub fn form_max_length(length int) FormRule {
	return FormRule{
		check:  .max_length
		length: length
	}
}

pub fn form_email() FormRule {
	return FormRule{
		check: .email
	}
}

pub fn form_digits() FormRule {
	return FormRule{
		check: .digits
	}
}

pub fn form_alphanumeric() FormRule {
	return FormRule{
		check: .alphanumeric
	}
}

// form_number checks for a number; pass none for a bound that does not apply.
pub fn form_number(min ?f64, max ?f64) FormRule {
	return FormRule{
		check: .number
		min:   min
		max:   max
	}
}

pub fn form_pattern(pattern string) FormRule {
	return FormRule{
		check:   .pattern
		pattern: pattern
	}
}

// form_equals checks that the value is other: give it the password when
// checking its confirmation.
pub fn form_equals(other string) FormRule {
	return FormRule{
		check: .equals
		other: other
	}
}

// FormValue is a field's value with the rules it must pass.
pub struct FormValue {
pub:
	field string // The FormField id the message belongs to.
	label string // Names the field in messages; "This field" when empty.
	value string
	rules []FormRule
}

fn form_plural(count int, word string) string {
	return if count == 1 { '${count} ${word}' } else { '${count} ${word}s' }
}

fn form_number_text(value f64) string {
	if math.abs(value) < 1e15 && value == math.round(value) {
		return i64(value).str()
	}
	return value.str()
}

// form_rule_message is a failed rule's message: its own, or a default naming
// the field.
fn form_rule_message(rule FormRule, name string) string {
	if rule.message.len > 0 {
		return rule.message
	}
	return match rule.check {
		.required {
			'${name} is required.'
		}
		.min_length {
			'${name} must be at least ${form_plural(rule.length, 'character')}.'
		}
		.max_length {
			'${name} must be at most ${form_plural(rule.length, 'character')}.'
		}
		.email {
			'Enter a valid email address.'
		}
		.digits {
			'${name} can only contain digits.'
		}
		.alphanumeric {
			'${name} can only contain letters and digits.'
		}
		.number {
			if low := rule.min {
				if high := rule.max {
					'${name} must be a number from ${form_number_text(low)} to ${form_number_text(high)}.'
				} else {
					'${name} must be a number of at least ${form_number_text(low)}.'
				}
			} else if high := rule.max {
				'${name} must be a number of at most ${form_number_text(high)}.'
			} else {
				'${name} must be a number.'
			}
		}
		.pattern {
			'${name} is not in the expected format.'
		}
		.equals {
			'${name} does not match.'
		}
	}
}

fn form_rule_passes(rule FormRule, value string) bool {
	return match rule.check {
		.required {
			value.trim_space().len > 0
		}
		.min_length {
			value.runes().len >= rule.length
		}
		.max_length {
			value.runes().len <= rule.length
		}
		.email {
			form_email_valid(value.trim_space())
		}
		.digits {
			value.bytes().all(it >= `0` && it <= `9`)
		}
		.alphanumeric {
			value.bytes().all(it.is_letter() || it.is_digit())
		}
		.number {
			form_number_passes(rule, value)
		}
		.pattern {
			form_pattern_matches(value, rule.pattern)
		}
		.equals {
			value == rule.other
		}
	}
}

fn form_number_passes(rule FormRule, value string) bool {
	number := number_input_parse(value.trim_space()) or { return false }
	if low := rule.min {
		if number < low {
			return false
		}
	}
	if high := rule.max {
		if number > high {
			return false
		}
	}
	return true
}

// form_check is the message of the first rule value fails, or '' when it
// passes them all. A blank value fails only required.
pub fn form_check(value string, label string, rules []FormRule) string {
	name := if label.trim_space().len > 0 { label.trim_space() } else { 'This field' }
	blank := value.trim_space().len == 0
	for rule in rules {
		if blank && rule.check != .required {
			continue
		}
		if !form_rule_passes(rule, value) {
			return form_rule_message(rule, name)
		}
	}
	return ''
}

// form_validate checks every value and maps the id of each field that fails
// to its first message. An empty map means the form is valid. When a field is
// listed more than once, its first failure wins.
pub fn form_validate(values []FormValue) map[string]string {
	mut errors := map[string]string{}
	for item in values {
		if item.field in errors {
			continue
		}
		message := form_check(item.value, item.label, item.rules)
		if message.len > 0 {
			errors[item.field] = message
		}
	}
	return errors
}

// The symbols RFC 5322 allows in the local part of an address without quotes.
const form_email_symbols = "!#$%&'*+-/=?^_`{|}~."

fn form_email_local_char(c u8) bool {
	return c.is_letter() || c.is_digit() || c >= 0x80 || form_email_symbols.index_u8(c) >= 0
}

fn form_domain_label_valid(part string) bool {
	if part.len == 0 || part.len > 63 || part[0] == `-` || part[part.len - 1] == `-` {
		return false
	}
	return part.bytes().all(it.is_letter() || it.is_digit() || it == `-` || it >= 0x80)
}

// form_email_valid accepts what people type as an address: one @, a local
// part of letters, digits and the usual symbols with no leading, trailing or
// doubled dot, and a domain of at least two dot-separated labels whose last
// is not all digits. Quoted local parts and IP-literal domains, which forms
// do not see, are refused; whether the address exists is not checked.
pub fn form_email_valid(address string) bool {
	if address.len > 254 || address.count('@') != 1 {
		return false
	}
	at := address.index_u8(`@`)
	local := address[..at]
	domain := address[at + 1..]
	if local.len == 0 || local.len > 64 || local.starts_with('.') || local.ends_with('.')
		|| local.contains('..') || !local.bytes().all(form_email_local_char(it)) {
		return false
	}
	parts := domain.split('.')
	if parts.len < 2 || !parts.all(form_domain_label_valid(it)) {
		return false
	}
	tld := parts[parts.len - 1]
	return tld.len >= 2 && !tld.bytes().all(it.is_digit())
}

// form_pattern_matches checks the whole value against a simple pattern: `#`
// is a digit, `A` an ASCII letter, `*` a letter or digit, `?` any character,
// `\` makes the next character literal, and `|` separates alternatives.
// Everything else stands for itself. `#####|#####-####` accepts US ZIP codes,
// `A#A #A#` Canadian postal codes.
pub fn form_pattern_matches(value string, pattern string) bool {
	chars := value.runes()
	mut alternative := []rune{}
	mut escaped := false
	for r in pattern.runes() {
		if escaped {
			alternative << `\\`
			alternative << r
			escaped = false
		} else if r == `\\` {
			escaped = true
		} else if r == `|` {
			if form_pattern_alternative(chars, alternative) {
				return true
			}
			alternative.clear()
		} else {
			alternative << r
		}
	}
	return form_pattern_alternative(chars, alternative)
}

// form_pattern_alternative matches chars against one alternative, in which an
// escaped character is a backslash followed by it.
fn form_pattern_alternative(chars []rune, pattern []rune) bool {
	mut i := 0
	mut p := 0
	for p < pattern.len {
		if i >= chars.len {
			return false
		}
		c := chars[i]
		token := pattern[p]
		ok := if token == `\\` && p + 1 < pattern.len {
			p++
			c == pattern[p]
		} else {
			match token {
				`#` { c >= `0` && c <= `9` }
				`A` { (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) }
				`*` { (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || (c >= `0` && c <= `9`) }
				`?` { true }
				else { c == token }
			}
		}
		if !ok {
			return false
		}
		i++
		p++
	}
	return i == chars.len
}
