#!/usr/bin/env ruby

require 'pathname'
ENV['BUNDLE_GEMFILE'] ||= File.expand_path("../../Gemfile",
  Pathname.new(__FILE__).realpath)

require 'rubygems'
require 'bundler'
Bundler.setup :squarespace_migration

require 'nokogiri'
require 'fileutils'
require 'open-uri'
require 'reverse_markdown'

module ReverseMarkdown
  module Converters
    class ImgWithClass < Base
      def convert(node)
        alt   = node['alt']
        src   = node['src']
        klass = node['class']
        title = extract_title(node)
        " ![#{alt}](#{src}#{title})#{"\n{: .#{klass} }" if klass}"
      end
    end

    register :img, ImgWithClass.new
  end
end

authors = {
  'tsummerville@fleetio.com' => 'Tony Summerville',
  'mchapman@rarestep.com' => 'Matt Chapman'
}

FileUtils.mkdir_p File.join('source', 'blog')

items = Nokogiri::XML(File.open 'fleetio-blog-posts.xml').css('items > item').select { |item|
  item.xpath('wp:post_type').text == 'post'
}

items.each_with_index do |item, i|
  title = item.xpath('title').text
  date = item.xpath('wp:post_date').text.split(' ').first
  link = item.xpath('link').text
  slug = link.split('/').last
  email = item.xpath('dc:creator').text
  author = authors[email]
  filename = date + '-' + slug

  puts
  puts "Converting #{"%03i" % (i + 1)} of #{items.size}..."
  puts %Q["#{title}"]

  content = Nokogiri.HTML(item.xpath('content:encoded').text)
  content.css('img').each do |img|
    img_dir = File.join('source', 'assets', 'images', filename)
    FileUtils.mkdir_p img_dir
    src = img[:src] || img[:"data-src"]

    img_filename = URI.escape URI.unescape(src.split('/').last.split('?').first.split('#').last.match(/.*?\.(png|jpg|jpeg)/i,)[0]).gsub(/\s+/, '_')
    puts "     #{img_filename}"

    File.open File.join(img_dir, img_filename), 'wb' do |f|
      f.write open(src).read
    end

    img[:src] = File.join(filename, img_filename)
    img[:class] = 'text-center'
  end

  File.open File.join('source', 'blog', filename + '.html.md'), 'w' do |f|
    f.write \
%Q[---
title: "#{title}"
slug: #{slug}
date: #{date}
author: #{author}
---

#{ReverseMarkdown.convert(content).strip}]
  end
end
