module ApplicationHelper
  def lighten_colour(hex_colour, amount=0.4)
    hex_colour = hex_colour.gsub('#','')
    rgb = hex_colour.scan(/../).map(&:hex)
    rgb.map! {|f| [(f + 255 * amount).round, 255].min }
    "#%02x%02x%02x" % rgb
  end
end
