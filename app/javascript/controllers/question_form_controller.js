import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "titleInput", "optionsWrapper",
    "shortAnswerPreview", "paragraphPreview", "optionsSection",
    "datePreview", "timePreview", "numberPreview", "submitButton"
  ]

  connect() {
    // Get initial question type from select
    const select = this.element.querySelector('select[name="question[question_type]"]')
    if (select) {
      this.handleInitialType(select.value)
    }
    this.validateForm()
    this.toggleFields()
    this.updateRatingPreview()
    
    // Add event listener for question type change
    select?.addEventListener('change', this.handleTypeChange.bind(this))
  }

  handleInitialType(type) {
    // Hide all previews
    this.hideAllPreviews()

    // Show appropriate preview based on type
    switch(type) {
      case 'short_answer':
        if (this.hasShortAnswerPreviewTarget) this.shortAnswerPreviewTarget.classList.remove('d-none')
        break
      case 'paragraph':
        if (this.hasParagraphPreviewTarget) this.paragraphPreviewTarget.classList.remove('d-none')
        break
      case 'multiple_choice':
      case 'checkboxes':
      case 'dropdown':
        if (this.hasOptionsSectionTarget) {
          this.optionsSectionTarget.classList.remove('d-none')
          this.optionsSectionTarget.style.display = 'block'
        }
        this.updateOptionIndicators(type)
        this.showOptionsContainer(true)
        
        // Hide correct checkboxes for these question types
        this.hideCorrectCheckboxes()
        break
      case 'yes_or_no':
        if (this.hasOptionsSectionTarget) {
          this.optionsSectionTarget.classList.remove('d-none')
          this.optionsSectionTarget.style.display = 'block'
        }
        this.updateOptionIndicators('multiple_choice')
        this.showOptionsContainer(true)
        // For Yes/No, we'll auto-populate the options
        this.createYesNoOptions()
        break
      case 'date':
        if (this.hasDatePreviewTarget) this.datePreviewTarget.classList.remove('d-none')
        break
      case 'time':
        if (this.hasTimePreviewTarget) this.timePreviewTarget.classList.remove('d-none')
        break
      case 'number':
        if (this.hasNumberPreviewTarget) this.numberPreviewTarget.classList.remove('d-none')
        break
      case 'rating':
        this.showRatingOptions(true)
        break
    }
  }

  handleTypeChange(event) {
    const type = event.target.value
    console.log("Question type changed to:", type)
    
    // Hide all previews first
    this.hideAllPreviews()
    
    // If coming from yes_or_no type, restore correct checkboxes
    if (type !== 'yes_or_no') {
      this.restoreCorrectCheckboxes()
      this.clearOptionInputs()
    }
    
    // Show appropriate preview based on type
    switch(type) {
      case 'short_answer':
        if (this.hasShortAnswerPreviewTarget) this.shortAnswerPreviewTarget.classList.remove('d-none')
        break
      case 'paragraph':
        if (this.hasParagraphPreviewTarget) this.paragraphPreviewTarget.classList.remove('d-none')
        break
      case 'multiple_choice':
      case 'checkboxes':
      case 'dropdown':
        console.log("Showing options section for:", type)
        if (this.hasOptionsSectionTarget) {
          this.optionsSectionTarget.classList.remove('d-none')
          this.optionsSectionTarget.style.display = 'block'
          
          // Ensure option inputs have required attribute enabled
          this.optionsSectionTarget.querySelectorAll('input[name*="[text]"]').forEach(input => {
            input.required = true
          })
        }
        this.updateOptionIndicators(type)

        // Ensure we have at least two options
        const nestedFormController = this.application.getControllerForElementAndIdentifier(
          this.element, 'nested-form'
        )
        const optionsCount = this.hasOptionsSectionTarget ? this.optionsSectionTarget.querySelectorAll('.option-item').length : 0
        if (optionsCount < 2) {
          if (nestedFormController) {
            if (optionsCount === 0) {
              nestedFormController.add()
              nestedFormController.add()
            } else if (optionsCount === 1) {
              nestedFormController.add()
            }
          }
        } else if (nestedFormController) {
          nestedFormController.updatePlaceholders()
        }
        
        // Hide correct checkboxes for these question types
        this.hideCorrectCheckboxes()
        break
      case 'yes_or_no':
        console.log("Showing Yes/No options")
        if (this.hasOptionsSectionTarget) {
          this.optionsSectionTarget.classList.remove('d-none')
          this.optionsSectionTarget.style.display = 'block'
        }
        this.updateOptionIndicators('multiple_choice')
        
        // Clear existing options and create Yes/No options
        this.createYesNoOptions()
        break
      case 'date':
        if (this.hasDatePreviewTarget) this.datePreviewTarget.classList.remove('d-none')
        break
      case 'time':
        if (this.hasTimePreviewTarget) this.timePreviewTarget.classList.remove('d-none')
        break
      case 'number':
        if (this.hasNumberPreviewTarget) this.numberPreviewTarget.classList.remove('d-none')
        break
      case 'rating':
        this.showRatingOptions(true)
        break
    }
  }

  clearOptionInputs() {
    const optionItems = this.hasOptionsSectionTarget ? this.optionsSectionTarget.querySelectorAll('.option-item') : this.element.querySelectorAll('.option-item')
    optionItems.forEach(item => {
      const textField = item.querySelector('input[name*="[text]"]')
      if (textField) {
        textField.value = ''
      }
      const correctBox = item.querySelector('input[type="checkbox"][name*="[correct]"]')
      if (correctBox) {
        correctBox.checked = false
      }
    })
  }

  hideAllPreviews() {
    console.log("Hiding all previews")
    if (this.hasShortAnswerPreviewTarget) this.shortAnswerPreviewTarget.classList.add('d-none')
    if (this.hasParagraphPreviewTarget) this.paragraphPreviewTarget.classList.add('d-none')
    if (this.hasDatePreviewTarget) this.datePreviewTarget.classList.add('d-none')
    if (this.hasTimePreviewTarget) this.timePreviewTarget.classList.add('d-none')
    if (this.hasNumberPreviewTarget) this.numberPreviewTarget.classList.add('d-none')
    
    // Hide options section and disable required attribute so non-option types can submit
    if (this.hasOptionsSectionTarget) {
      this.optionsSectionTarget.classList.add('d-none')
      this.optionsSectionTarget.style.display = 'none'
      this.optionsSectionTarget.querySelectorAll('input[name*="[text]"]').forEach(input => {
        input.required = false
      })
    }
    this.showRatingOptions(false)
  }

  updateOptionIndicators(type) {
    const indicators = this.element.querySelectorAll('.option-indicator i')
    indicators.forEach(indicator => {
      indicator.className = `bi ${
        type === 'multiple_choice' ? 'bi-circle' :
        type === 'checkboxes' ? 'bi-square' :
        'bi-chevron-down'
      }`
    })
  }

  validateForm() {
    if (!this.hasTitleInputTarget || !this.hasSubmitButtonTarget) return
    const title = this.titleInputTarget.value.trim()
    this.submitButtonTarget.disabled = title.length === 0
  }

  showOptionsContainer(show) {
    console.log("showOptionsContainer called with:", show)
    if (!this.hasOptionsSectionTarget) return
    if (show) {
      this.optionsSectionTarget.classList.remove('d-none')
      this.optionsSectionTarget.style.display = 'block'
    } else {
      this.optionsSectionTarget.classList.add('d-none')
      this.optionsSectionTarget.style.display = 'none'
    }
  }
  
  showRatingOptions(show) {
    const ratingOptions = this.element.querySelector('.rating-options') || document.querySelector('.rating-options')
    if (ratingOptions) {
      ratingOptions.style.display = show ? 'flex' : 'none'
    }
  }
  
  toggleFields() {
    const questionTypeSelect = this.element.querySelector('select[name="question[question_type]"]')
    const questionType = questionTypeSelect ? questionTypeSelect.value : ''
    
    // Hide/show options container based on question type
    this.showOptionsContainer(['multiple_choice', 'checkboxes', 'dropdown'].includes(questionType))
    
    // Hide/show rating options based on question type
    this.showRatingOptions(questionType === 'rating')
    
    // Hide correct checkboxes for multiple choice, checkbox, dropdown, and yes/no
    if (['multiple_choice', 'checkboxes', 'dropdown', 'yes_or_no'].includes(questionType)) {
      this.hideCorrectCheckboxes()
    }
  }
  
  updateRatingPreview() {
    const maxRatingSelect = document.getElementById('question_max_rating')
    if (maxRatingSelect) {
      maxRatingSelect.addEventListener('change', () => {
        const maxRating = parseInt(maxRatingSelect.value)
        const previewContainer = document.querySelector('.rating-preview')
        
        // Clear existing stars
        previewContainer.innerHTML = ''
        
        // Add new stars based on selected max rating
        for (let i = 1; i <= maxRating; i++) {
          const star = document.createElement('i')
          star.className = 'bi bi-star-fill text-warning fs-3 me-1'
          previewContainer.appendChild(star)
        }
      })
    }
  }
  
  toggleRequired(event) {
    // This method handles the required checkbox toggle
    const isRequired = event.target.checked
    console.log(`Question is now ${isRequired ? 'required' : 'optional'}`)
    
    // You can add additional logic here if needed
    // For example, updating UI elements based on the required status
  }

  createYesNoOptions() {
    // Clear existing options first
    const optionsContainer = this.optionsSectionTarget.querySelector('[data-nested-form-target="items"]')
    if (optionsContainer) {
      optionsContainer.innerHTML = ''
      
      // Use the nested form controller to add Yes/No options
      const nestedFormController = this.application.getControllerForElementAndIdentifier(
        this.element, 'nested-form'
      )
      
      if (nestedFormController) {
        // Hide the "Add Option" button for Yes/No questions
        const addOptionButton = this.optionsSectionTarget.querySelector('button[data-action="nested-form#add"]')
        if (addOptionButton) {
          addOptionButton.style.display = 'none'
        }
        
        // Add two options (Yes and No) programmatically
        // First, add the options
        nestedFormController.add()
        nestedFormController.add()
        
        // Now get all option items
        const optionItems = optionsContainer.querySelectorAll('.option-item')
        
        // Set values for Yes and No options
        if (optionItems.length >= 2) {
          const yesOption = optionItems[0]
          const noOption = optionItems[1]
          
          // Set text for Yes option
          const yesTextField = yesOption.querySelector('input[type="text"]')
          if (yesTextField) yesTextField.value = 'Yes'
          
          // Set text for No option
          const noTextField = noOption.querySelector('input[type="text"]')
          if (noTextField) noTextField.value = 'No'
          
          // Hide correct checkboxes for both options
          optionItems.forEach(option => {
            const correctCheckboxContainer = option.querySelector('.form-check')
            if (correctCheckboxContainer) {
              correctCheckboxContainer.style.display = 'none'
            }
            
            // Hide delete buttons
            const deleteButton = option.querySelector('button[data-action="nested-form#remove"]')
            if (deleteButton) {
              deleteButton.style.display = 'none'
            }
          })
          
          // Also hide correct checkboxes in the template for any new options
          const template = this.element.querySelector('[data-nested-form-target="template"]')
          if (template) {
            const templateCorrectCheckbox = template.querySelector('.form-check')
            if (templateCorrectCheckbox) {
              templateCorrectCheckbox.dataset.yesNoHidden = 'true'
            }
          }
        }
      }
    }
  }

  restoreCorrectCheckboxes() {
    // Restore visibility of all correct checkboxes
    const checkboxContainers = this.element.querySelectorAll('.form-check')
    checkboxContainers.forEach(container => {
      container.style.display = ''
    })
    
    // Also restore in template
    const template = this.element.querySelector('[data-nested-form-target="template"]')
    if (template) {
      const templateCorrectCheckbox = template.querySelector('.form-check')
      if (templateCorrectCheckbox) {
        delete templateCorrectCheckbox.dataset.yesNoHidden
      }
    }
    
    // Restore the "Add Option" button
    const addOptionButton = this.optionsSectionTarget.querySelector('button[data-action="nested-form#add"]')
    if (addOptionButton) {
      addOptionButton.style.display = ''
    }
    
    // Restore delete buttons
    const optionItems = this.element.querySelectorAll('.option-item')
    optionItems.forEach(option => {
      // Restore delete buttons
      const deleteButton = option.querySelector('button[data-action="nested-form#remove"]')
      if (deleteButton) {
        deleteButton.style.display = ''
      }
    })
  }

  hideCorrectCheckboxes() {
    // Hide correct checkboxes for all options
    const optionItems = this.element.querySelectorAll('.option-item')
    optionItems.forEach(option => {
      const correctCheckboxContainer = option.querySelector('.form-check')
      if (correctCheckboxContainer) {
        correctCheckboxContainer.style.display = 'none'
      }
    })
    
    // Also hide correct checkboxes in the template for any new options
    const template = this.element.querySelector('[data-nested-form-target="template"]')
    if (template) {
      const templateCorrectCheckbox = template.querySelector('.form-check')
      if (templateCorrectCheckbox) {
        templateCorrectCheckbox.style.display = 'none'
      }
    }
  }
} 