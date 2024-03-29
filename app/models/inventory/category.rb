# encoding: utf-8
class Inventory::Category < Inventory::Base
  include EncodedImageUploadable
  include LikeSearchable

  has_many :sections, class_name: "Inventory::Section",
                      foreign_key: "inventory_category_id",
                      autosave: true
  has_many :fields, through: :sections,
                    autosave: true
  has_many :items, class_name: "Inventory::Item", foreign_key: "inventory_category_id"
  has_many :statuses, class_name: "Inventory::Status", foreign_key: "inventory_category_id"
  has_many :formulas, class_name: "Inventory::Formula", foreign_key: "inventory_category_id"

  has_and_belongs_to_many :reports_categories, class_name: 'Reports::Category',
                          association_foreign_key: 'reports_category_id',
                          foreign_key: 'inventory_category_id'

  accepts_nested_attributes_for :statuses

  mount_uploader :icon, IconUploader
  mount_uploader :marker, MarkerUploader
  mount_uploader :pin, PinUploader

  validates :title, presence: true, uniqueness: true
  validates :icon, integrity: true, presence: true
  validates :pin, integrity: true, presence: true
  validates :marker, integrity: true, presence: true
  validates :color, presence: true, css_hex_color: true
  validates :plot_format, presence: true, inclusion: { in: %w(pin marker) }
  validates :require_item_status, inclusion: { in: [false, true] }

  before_validation :set_default_values
  before_create :create_default_sections

  accepts_encoded_file :icon, :marker, :pin
  expose_multiple_versions :icon, :marker, :pin

  def entity
    Entity.new(self)
  end

  def original_icon
    self.icon.to_s
  end

  class Entity < Grape::Entity
    expose :id
    expose :title
    expose :description
    expose :plot_format
    expose :pin_structure, as: :pin
    expose :marker_structure, as: :marker
    expose :icon_structure, as: :icon
    expose :require_item_status
    expose :color
    expose :original_icon
    expose :sections, using: Inventory::Section::Entity

    with_options(if: { display_type: 'full' }) do
      expose :statuses, using: Inventory::Status::Entity
    end

    expose :created_at
    expose :updated_at, if: { display_type: 'backend' }
  end

  protected
    def create_default_sections
      section = self.sections.build(title: "Localização", required: true, location: true)
      section.fields.build(title: "latitude",
                           label: "Latitude",
                           required: true,
                           location: true,
                           kind: "decimal"
                          )
      section.fields.build(title: "longitude",
                           label: "Longitude",
                           required: true,
                           location: true,
                           kind: "decimal"
                          )

      section.fields.build(title: "address",
                           label: "Endereço",
                           location: true,
                           kind: "text"
                          )

      section.fields.build(title: "postal_code",
                           label: "CEP",
                           location: true,
                           kind: "text"
                          )

      section.fields.build(title: "district",
                           label: "Bairro",
                           location: true,
                           kind: "text"
                          )

      section.fields.build(title: "city",
                           label: "Cidade",
                           location: true,
                           kind: "text"
                          )

      section.fields.build(title: "state",
                           label: "Estado",
                           location: true,
                           kind: "text"
                          )

      section.fields.build(title: "codlog",
                           label: "Codlog",
                           location: true,
                           kind: "text"
                          )

      section.fields.build(title: "road_classification",
                           label: "Classificação Viária",
                           location: true,
                           kind: "text"
                          )
    end

    def set_default_values
      self.require_item_status = false if require_item_status.nil?
      true
    end
end
