# Aardwolf Switch Weapons Plugin

A MUSHclient plugin for Aardwolf MUD that automatically switches between weapons based on damage type.

## Features

- **Smart Weapon Selection**: Automatically finds the best weapons (by average damage) for each damage type
- **Level-Aware**: Only considers weapons you can currently wear based on your effective level (level + tier * 10)
- **Dual Wielding Support**: Attempts to equip both wielded and second weapon slots when possible
- **Weight Management**: Respects the rule that second weapons must be half the weight or less of wielded weapons
- **Damage Type Cycling**: Easily cycle through all available damage types in alphabetical order
- **Status Display**: View all your best weapons organized by damage type

## Requirements

- MUSHclient 5.07 or higher
- Aardwolf MUD connection
- GMCP Handler plugin (id: 3e7dedbe37e44942dd46d264)
- Durel's Inventory Plugin (aard_inventory, id: 88c86ea252fc1918556df9fe)

**Important**: This plugin requires the updated Aardwolf Inventory (dinv) plugin with new search methods. You must use the fork found at:

**https://github.com/AardPlugins/aard-inventory**

The standard dinv plugin does not have the `SearchAndReturn` method required by this plugin.

## Installation

1. Copy `Aardwolf_Switch_Weapons.xml` and `Aardwolf_Switch_Weapons.lua` to your MUSHclient plugins directory
2. In MUSHclient, go to File → Plugins
3. Click "Add" and select `Aardwolf_Switch_Weapons.xml`
4. Make sure you have a current inventory built with `dinv build confirm`

## Commands

- `switch` - Cycle to the next damage type
- `switch <damage_type>` - Switch to a specific damage type (e.g., `switch fire`, `switch mental`)
- `switch status` - Show the best weapons for each damage type
- `switch help` - Display help information
- `switch update` - Update the plugin to the latest version
- `switch reload` - Reload the plugin

## How It Works

1. The plugin queries your inventory using the dinv plugin
2. It filters weapons by your effective level (level + tier * 10)
3. For each damage type, it finds the weapon with the highest average damage
4. When you type `switch`, it cycles to the next damage type alphabetically
5. It equips the best wielded weapon and attempts to equip a second weapon if weight allows

## Weight Rules

The plugin follows Aardwolf's dual wielding rules:
- Second weapon must be half the weight or less than the wielded weapon
- If a suitable second weapon isn't available, only the wielded slot is filled
- Priority is given to keeping the wielded slot filled with the best weapon

## Examples

```
> switch
[Switch] Switched to acid damage type
[Switch]   Wielded: a corroded blade (Ave: 145)
[Switch]   Second:  a small acid dagger (Ave: 89)

> switch fire
[Switch] Switched to fire damage type
[Switch]   Wielded: flaming sword of doom (Ave: 178)

> switch status
[Switch] Best Weapons by Damage Type:
================================================================================
Damage Type  | Weapon Name                              | Level | Ave Dam
--------------------------------------------------------------------------------
  acid       | a corroded blade                         | 150   | 145
* fire       | flaming sword of doom                    | 175   | 178
  mental     | mind blade                               | 160   | 152
  pierce     | deadly rapier                            | 155   | 148
================================================================================
Current damage type: fire (* = currently equipped)
```

## Troubleshooting

**No weapons found**: Make sure you've run `dinv build confirm` to populate your inventory database.

**Wrong weapons selected**: Run `dinv refresh` to update your inventory data.

**Plugin not responding**: Try `switch reload` to restart the plugin.

## Author

Created by deathr for Aardwolf MUD

## License

MIT License - Feel free to modify and distribute
