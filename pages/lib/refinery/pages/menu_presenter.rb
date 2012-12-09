require 'active_support/core_ext/string'
require 'active_support/configurable'
require 'action_view/helpers/tag_helper'
require 'action_view/helpers/url_helper'

module Refinery
  module Pages
    class MenuPresenter
      include ActionView::Helpers::TagHelper
      include ActionView::Helpers::UrlHelper
      include ActiveSupport::Configurable

      config_accessor :roots, :menu_tag, :list_tag, :list_item_tag, :css, :dom_id, :levels
      self.dom_id = 'menu'
      self.css = 'menu clearfix'
      self.menu_tag = :nav
      self.list_tag = :ul
      self.list_item_tag = :li
      def roots
        config.roots.presence || collection.roots
      end

      attr_accessor :context, :collection
      delegate :output_buffer, :output_buffer=, :to => :context

      def initialize(collection, context)
        self.collection = collection
        self.context = context
      end

      def to_html
        render_menu(roots) if roots.present?
      end

      def render_menu(items)
        content_tag(menu_tag, :id => dom_id, :class => css) do
          render_menu_items(items)
        end
      end

      def render_menu_item(menu_item, index)
        content_tag(list_item_tag, :class => menu_item_css(menu_item, index)) do
          buffer = ActiveSupport::SafeBuffer.new
          buffer << link_to(menu_item.title, context.refinery.url_for(menu_item.url))
          buffer << render_menu_items(menu_item_children(menu_item))
          buffer
        end
      end

      def render_menu_items(menu_items)
        if menu_items.present?
          content_tag(list_tag) do
            menu_items.each_with_index.inject(ActiveSupport::SafeBuffer.new) do |buffer, (item, index)|
              buffer << render_menu_item(item, index)
            end
          end
        end
      end

      # Determines whether any page underneath the supplied page is the current page according to rails.
      # Just calls selected_page? for each descendant of the supplied page
      # unless it first quickly determines that there are no descendants.
      def descendant_page_selected?(page)
        page.has_children? && page.descendants.any?(&method(:selected_page?))
      end

      def selected_page_or_descendant_page_selected?(page)
        selected_page?(page) || descendant_page_selected?(page)
      end

      # Determine whether the supplied page is the currently open page according to Refinery.
      def selected_page?(page)
        path = context.request.path
        path = path.force_encoding('utf-8') if path.respond_to?(:force_encoding)

        # Ensure we match the path without the locale, if present.
        if %r{^/#{::I18n.locale}/} === path
          path = path.split(%r{^/#{::I18n.locale}}).last.presence || "/"
        end

        # First try to match against a "menu match" value, if available.
        return true if page.try(:menu_match).present? && path =~ Regexp.new(page.menu_match)

        # Find the first url that is a string.
        url = [page.url]
        url << ['', page.url[:path]].compact.flatten.join('/') if page.url.respond_to?(:keys)
        url = url.last.match(%r{^/#{::I18n.locale.to_s}(/.*)}) ? $1 : url.detect{|u| u.is_a?(String)}

        # Now use all possible vectors to try to find a valid match
        [path, URI.decode(path)].include?(url) || path == "/#{page.original_id}"
      end

      def menu_item_css(menu_item, index)
        css = []

        css << Refinery::Core.menu_css[:selected] if selected_page_or_descendant_page_selected?(menu_item)
        css << Refinery::Core.menu_css[:first] if index == 0
        css << Refinery::Core.menu_css[:last] if index == menu_item.shown_siblings.length

        css.reject(&:blank?)
      end

      def menu_item_children(menu_item)
        if !levels || menu_item.ancestors.length < levels
          menu_item.children
        else
          []
        end
      end

    end
  end
end
