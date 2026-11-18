#
# Copyright (C) 2026
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=mt7981-eeprom-default
PKG_VERSION:=1
PKG_RELEASE:=1
PKG_LICENSE:=BSD-3-Clause-Clear

include $(INCLUDE_DIR)/package.mk

define Package/mt7981-eeprom-default
  SECTION:=firmware
  CATEGORY:=Firmware
  TITLE:=MediaTek MT7981 default EEPROM (MT7976 DBDC)
  PKGARCH:=all
endef

define Package/mt7981-eeprom-default/description
  Fallback calibration data for MT7981 + MT7976 DBDC radios. Needed on boards
  that do not expose factory calibration through a dedicated flash partition.
endef

define Build/Compile
endef

define Package/mt7981-eeprom-default/install
	$(INSTALL_DIR) $(1)/lib/firmware/mediatek
	$(INSTALL_DATA) ./files/mt7981_eeprom_mt7976_dbdc.bin \
		$(1)/lib/firmware/mediatek/mt7981_eeprom_mt7976_dbdc.bin
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/60-luci-ucode \
		$(1)/etc/uci-defaults/60-luci-ucode
	$(INSTALL_BIN) ./files/etc/uci-defaults/61-fw-env-config \
		$(1)/etc/uci-defaults/61-fw-env-config
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/mt7981-eeprom \
		$(1)/etc/init.d/mt7981-eeprom
	$(INSTALL_DIR) $(1)/etc/rc.d
	ln -sf ../init.d/mt7981-eeprom $(1)/etc/rc.d/S09mt7981-eeprom
endef

$(eval $(call BuildPackage,mt7981-eeprom-default))
