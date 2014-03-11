
jQuery(function() {
  $.miniAlert = function(element, options) {
    var addButton, bindButtonEvent, init, removeElement, setState,
      _this = this;
    this.defaults = {
      text: 'x',
      cssClass: 'close',
      position: 'before',
      effect: 'basic',
      duration: 100,
      onLoad: function() {},
      onHide: function() {},
      onHidden: function() {}
    };
    this.state = '';
    this.settings = {};
    this.$element = $(element);
    setState = function(state) {
      this.state = state;
    };
    this.getState = function() {
      return state;
    };
    this.getSetting = function(settingKey) {
      return this.settings[settingKey];
    };
    this.callSettingFunction = function(functionName, args) {
      if (args == null) {
        args = [this.$element, this.$button];
      }
      return this.settings[functionName].apply(this, args);
    };
    removeElement = function() {
      _this.$element.remove();
      setState('hidden');
      return _this.callSettingFunction('onHidden', []);
    };
    addButton = function() {
      options = {
        "class": _this.settings.cssClass,
        text: _this.settings.text
      };
      _this.$button = $('<button />', options);
      if (_this.settings.position === 'after') {
        return _this.$button.appendTo(_this.$element);
      } else {
        return _this.$button.prependTo(_this.$element);
      }
    };
    bindButtonEvent = function() {
      return _this.$button.bind('click', function(e) {
        e.preventDefault();
        setState('hiding');
        _this.callSettingFunction('onHide');
        if (_this.settings.effect === 'fade') {
          return _this.$element.fadeOut(_this.settings.duration, removeElement);
        } else if (_this.settings.effect === 'slide') {
          return _this.$element.slideUp(_this.settings.duration, removeElement);
        } else {
          return removeElement();
        }
      });
    };
    init = function() {
      setState('loading');
      _this.settings = $.extend({}, _this.defaults, options);
      addButton();
      bindButtonEvent();
      setState('loaded');
      return _this.callSettingFunction('onLoad');
    };
    init();
    return this;
  };
  return $.fn.miniAlert = function(options) {
    return this.each(function() {
      var plugin;
      if (void 0 === ($(this)).data('miniAlert')) {
        plugin = new $.miniAlert(this, options);
        return ($(this)).data('miniAlert', plugin);
      }
    });
  };
});
