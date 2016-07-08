/*
 * Copyright (c) 2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import Cocoa

enum FileType {

  case Apps(bytes: Int64, percent: Double)
  case Photos(bytes: Int64, percent: Double)
  case Audio(bytes: Int64, percent: Double)
  case Movies(bytes: Int64, percent: Double)
  case Other(bytes: Int64, percent: Double)

  var fileTypeInfo: (bytes: Int64, percent: Double) {
    switch self {
    case .Apps(let bytes, let percent):
      return (bytes: bytes, percent: percent)

    case .Photos(let bytes, let percent):
      return (bytes: bytes, percent: percent)

    case .Audio(let bytes, let percent):
      return (bytes: bytes, percent: percent)

    case .Movies(let bytes, let percent):
      return (bytes: bytes, percent: percent)

    case .Other(let bytes, let percent):
      return (bytes: bytes, percent: percent)
    }
  }

  var name: String {
    switch self {
    case .Apps(_, _):
      return "Apps"
    case .Audio(_, _):
      return "Audio"
    case .Movies(_, _):
      return "Movies"
    case .Photos(_, _):
      return "Photos"
    case .Other(_, _):
      return "Other"
    }
  }
}

struct FilesDistribution {
  let capacity: Int64
  let available: Int64
  var distribution = [FileType]()
}

struct VolumeInfo {
  let name: String
  let volumeType: String
  let image: NSImage?
  let capacity: Int64
  let available: Int64
  let removable: Bool
  let fileDistribution: FilesDistribution
}

extension FilesDistribution {
  static private func randomPercentage() -> Double {
    // random percentage between 15->20
    let rand = arc4random_uniform(15) + 5
    return Double(rand) / 100.0
  }

  static func randomDistributionWithCapacity(capacity: Int64, available: Int64) -> FilesDistribution? {
    guard capacity > 0 else {
      return nil
    }
    let used = Double(capacity - available)
    let apps = Int64(randomPercentage() * used)
    let appsPercent = Double(apps) / Double(capacity)
    let photos = Int64(randomPercentage() * used)
    let photosPercent = Double(photos) / Double(capacity)
    let audio = Int64(randomPercentage() * used)
    let audioPercent = Double(audio) / Double(capacity)
    let movies = Int64(randomPercentage() * used)
    let moviesPercent = Double(movies) / Double(capacity)
    let other = Int64(used) - (apps + photos + audio + movies)
    let otherPercent = Double(other) / Double(capacity)

    let distribution: [FileType] = [
      .Apps(bytes: apps, percent: appsPercent),
      .Photos(bytes: photos, percent: photosPercent),
      .Audio(bytes: audio, percent: audioPercent),
      .Movies(bytes: movies, percent: moviesPercent),
      .Other(bytes: other, percent: otherPercent)
    ]

    let fileDistribution = FilesDistribution(capacity: capacity, available: available, distribution: distribution)

    return fileDistribution
  }
}

extension VolumeInfo {
  static func volumeInfo(volumeURL: NSURL) -> VolumeInfo? {
    var nameResource: AnyObject?, removableResource: AnyObject?, capacityResource: AnyObject?,
    availableSpaceResource: AnyObject?, localDiskResource: AnyObject?

    do {
      try volumeURL.getResourceValue(&nameResource, forKey: NSURLVolumeNameKey)
      try volumeURL.getResourceValue(&capacityResource, forKey: NSURLVolumeTotalCapacityKey)
      try volumeURL.getResourceValue(&removableResource, forKey: NSURLVolumeIsRemovableKey)
      try volumeURL.getResourceValue(&availableSpaceResource, forKey: NSURLVolumeAvailableCapacityKey)
      try volumeURL.getResourceValue(&localDiskResource, forKey: NSURLVolumeIsLocalKey)
    } catch {
      return nil
    }

    guard let name = nameResource as? String,
      capacity = capacityResource?.longLongValue as Int64?,
      removable = removableResource as? Bool,
      available = availableSpaceResource?.longLongValue as Int64?,
      isLocal = localDiskResource as? Bool,
      fileDistribution = FilesDistribution.randomDistributionWithCapacity(capacity, available: available) where isLocal else {
        return nil
    }

    var image: NSImage?
    if let volumePath = volumeURL.path {
      image = NSWorkspace.sharedWorkspace().iconForFile(volumePath)
    }

    let volumeInfo = VolumeInfo(name: name, volumeType: "", image: image,
                                capacity: capacity, available: available,
                                removable: removable, fileDistribution: fileDistribution)

    return volumeInfo
  }

  static func mountedVolumes() -> [VolumeInfo] {
    let keysToRead = [
      NSURLVolumeIsRemovableKey,
      NSURLVolumeLocalizedNameKey,
      NSURLVolumeIsLocalKey,
      NSURLVolumeTotalCapacityKey,
      NSURLVolumeUUIDStringKey,
      NSURLVolumeAvailableCapacityKey
    ]

    guard let volumes = NSFileManager.defaultManager()
      .mountedVolumeURLsIncludingResourceValuesForKeys(keysToRead,
                                                       options: [.SkipHiddenVolumes]) else {
                                                        return []
    }

    var volumesInfo = [VolumeInfo]()

    for volumeURL in volumes {
      if let info = volumeInfo(volumeURL) {
        volumesInfo.append(info)
      }
    }
    return volumesInfo
  }
}
