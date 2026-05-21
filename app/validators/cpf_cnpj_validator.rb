class CpfCnpjValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    clean = value.gsub(/\D/, "")
    valid = clean.length == 11 ? CPF.valid?(value, strict: false) : CNPJ.valid?(value, strict: false)

    unless valid
      record.errors.add(attribute, options[:message] || :invalid)
    end
  end
end
