module Document
  extend ActiveSupport::Concern
  module ClassMethods
    def collection
      Store[self.to_s.tableize]
    end
    def find_by_id(id)
      found = collection.find_one(Id.from_string(id))
      found.nil? ? nil : self.new(unmap(found))
    end
    def find_one(selector = {})
      found = collection.find_one(map(selector))
      found.nil? ? nil : self.new(unmap(found))
    end
    def create(attributes, opts = {})
      attributes[:_id] = collection.save(map(attributes), opts)
      self.new(attributes)
    end
    def create!(attributes)
      create(attributes, {:safe => true})
    end
    def find(selector={}, opts={})
      collection.find(map(selector), opts)
    end
    def remove(selector={})
      collection.remove(map(selector))
    end
    def count(selector={})
      collection.find(map(selector)).count
    end
    def mongo_accessor(map)
      @map = map
      @unmap = {}
      map.each do |k,v|
        attr_accessor k
        @unmap[v.to_s] = k
      end
    end
    def map(raw)
      return {} if raw.blank? || !raw.is_a?(Hash)
      hash = {}
      raw.each do |key, value|
        real_key = @map.include?(key) ? @map[key] : key
        hash[real_key] = value.is_a?(Hash) ? map(value) : value
      end
      return hash
    end
    def unmap(raw)
      return {} if raw.blank? || !raw.is_a?(Hash)
      hash = {}
      raw.each do |key, value|
        real_key = @unmap.include?(key) ? @unmap[key] : key
        hash[real_key] = value
        hash.merge!(unmap(value)) if value.is_a?(Hash)
      end
      return hash
    end
  end
  module InstanceMethods
    def initialize(attributes = {})
      attributes[:_id] = Id.new unless attributes.include?('_id') || attributes.include?(:_id)
      @attributes = attributes
      attributes.each do |k,v|
        send("#{k}=", v)  unless k == :_id || k == '_id' 
      end
    end
    def id
      @attributes[:_id] || @attributes['_id']
    end
    def [](name)
      @attributes[name]
    end
    def ==(other)
      other.class == self.class && id == other.id
    end
    def attributes
      @attributes
    end
    def collection
      self.class.collection
    end
    def save
      collection.save(self.class.map(@attributes))
    end
  end
end