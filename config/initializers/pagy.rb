# Pagy initializer
require "pagy/extras/array"
require "pagy/extras/bootstrap"
require "pagy/extras/overflow"

Pagy::DEFAULT[:items]    = 15
Pagy::DEFAULT[:size]     = 7
Pagy::DEFAULT[:overflow] = :last_page
