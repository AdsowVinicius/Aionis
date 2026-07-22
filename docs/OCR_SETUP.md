# Tesseract OCR Setup Guide

Este documento descreve como usar Tesseract OCR no projeto Aionis para extrair texto de imagens.

## O que foi adicionado

### 1. **Gemfile**
- Adicionada a gem `rtesseract` para integração com Tesseract

### 2. **Dockerfile**
- Instalação automática do Tesseract OCR e suas dependências (`tesseract-ocr`, `libtesseract-dev`)

### 3. **lib/ocr_service.rb**
- Serviço centralizado para operações de OCR
- Suporta processamento de arquivos e Active Storage attachments
- Suporta múltiplos idiomas (português padrão)

### 4. **app/jobs/extract_text_job.rb**
- Background job para processar OCR de forma assíncrona
- Ideal para não bloquear requisições HTTP

## Como usar

### Opção 1: Extração síncrona simples

```ruby
# Em um controller ou modelo
text = OcrService.extract_text("/path/to/image.jpg", language: 'por')
puts text
```

### Opção 2: Com Active Storage attachments

```ruby
class Document < ApplicationRecord
  has_one_attached :image
end

# Extrair texto da imagem
doc = Document.first
text = OcrService.extract_from_attachment(doc.image, language: 'por')
```

### Opção 3: Processamento assíncrono com Background Job

```ruby
# Enfileirar OCR em background
ExtractTextJob.perform_later(
  'Document',      # classe do modelo
  doc.id,          # ID do registro
  'image',         # nome do attachment
  'extracted_text' # campo para salvar o texto extraído
)

# Mais tarde, seu modelo terá o texto extraído em doc.extracted_text
```

## Idiomas Suportados

O Tesseract suporta muitos idiomas. Alguns exemplos:

- `eng` - Inglês
- `por` - Português (padrão)
- `spa` - Espanhol
- `fra` - Francês
- `deu` - Alemão

Para usar outro idioma:

```ruby
OcrService.extract_text(image_path, language: 'eng')
```

## Verificar se Tesseract está disponível

```ruby
OcrService.available? # retorna true/false
```

## Exemplo de modelo com OCR automático

```ruby
class Invoice < ApplicationRecord
  has_one_attached :document
  
  after_create :extract_invoice_text
  
  def extract_invoice_text
    return unless document.attached?
    ExtractTextJob.perform_later(self.class.name, id, 'document', 'extracted_text')
  end
end
```

## Troubleshooting

### Erro: "Tesseract not found"
- Verifique se o Dockerfile foi atualizado
- Redeploy a aplicação
- Em desenvolvimento local, instale Tesseract: `brew install tesseract` (Mac) ou `apt-get install tesseract-ocr` (Linux)

### OCR retorna texto vazio
- Verifique a qualidade da imagem
- Tente com `language: 'eng'` para testar
- Verifique os logs do job background

### Performance
- Imagens muito grandes podem levar mais tempo
- Processe imagens em background jobs quando possível
- Considere redimensionar imagens antes de processar

