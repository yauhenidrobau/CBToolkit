//
//  CBPhotoFetcher.swift
//  CBToolkit
//
//  Created by Wes Byrne on 12/6/14.
//  Copyright (c) 2014 WCBMedia. All rights reserved.
//

import Foundation
import UIKit


public typealias CBImageFetchCallback = (image: UIImage?, error: NSError?)->Void
public typealias CBProgressBlock = (progress: Float)->Void


public class CBPhotoFetcher: NSObject, CBImageFetchRequestDelegate {
    
    private var imageCache: NSCache! = NSCache()
    private var inProgress: [String: CBImageFetchRequest]! = [:]
    
    public class var sharedFetcher : CBPhotoFetcher {
        struct Static {
            static let instance : CBPhotoFetcher = CBPhotoFetcher()
        }
        return Static.instance
    }
    
    override init() {
        super.init()
    }
    
    
    public func clearCache() {
        imageCache.removeAllObjects()
    }
    
    public func cancelAll() {
        inProgress.removeAll(keepCapacity: false)
    }
    
    // Clears any callbacks for the url
    // The image will continue to load and cache for next time
    public func cancelFetchForUrl(url: String) {
        if let request = inProgress[url] {
            request.cancelRequest()
        }
        inProgress.removeValueForKey(url)
    }
    
    public func fetchImageAtURL(imgUrl: String!, completion: CBImageFetchCallback!, progressBlock: CBProgressBlock? = nil) {
        assert(completion != nil, "CBPhotoFetcher Error: You must suppy a completion block when loading an image")
        
        // The image is chached
        if let cachedImage = imageCache.objectForKey(imgUrl) as? UIImage  {
            completion(image: cachedImage, error: nil)
            return
        }
        
        // A request is already going. add it on
        if let request = inProgress[imgUrl] {
            request.completionBlocks.append(completion)
            if progressBlock != nil { request.progressBlocks.append(progressBlock!) }
            return
        }
        
        
        var request = CBImageFetchRequest(imageURL: imgUrl, completion: completion, progress: progressBlock)
        inProgress[imgUrl] = request
        request.delegate = self
        request.start()
        
        
        var url = NSURL(string: imgUrl)
        if url == nil {
            println("Error creating URL for image url: \(imgUrl)")
            completion(image: nil, error: NSError(domain: "SmartReader", code: 0, userInfo: nil))
            return
        }
        
//        pendingFetches[imgUrl] = [completion]
//        
//        var request = NSURLRequest(URL: url!)
//        NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) { (response, data, error) -> Void in
//            var image: UIImage? = nil
//            var urlStr = request.URL!.absoluteString!
//            
//            if (error == nil) {
//                image = UIImage(data: data)
//                self.imageCache.setObject(image!, forKey: urlStr)
//            }
//            
//            var callbacks = self.pendingFetches[urlStr]
//            if (callbacks == nil) {
//                println("callback not found after fetch for url: \(urlStr)")
//                return
//            }
//            
//            for cb in callbacks! {
//                cb(image: image, error: error)
//            }
//            self.pendingFetches.removeValueForKey(urlStr)
//        }
    }
    
    func fetchRequestDidFinish(url: String, image: UIImage?) {
        inProgress.removeValueForKey(url)
        if image != nil {
            imageCache.setObject(image!, forKey: url)
        }
        else {
            imageCache.removeObjectForKey(url)
        }
    }
    
    
    
    
}




protocol CBImageFetchRequestDelegate {
    func fetchRequestDidFinish(url: String, image: UIImage?)
}


class CBImageFetchRequest : NSObject, NSURLConnectionDelegate, NSURLConnectionDataDelegate {
    
    var baseURL : String!
    var completionBlocks: [CBImageFetchCallback]! = []
    var progressBlocks : [CBProgressBlock]! = []
    
    var imgData : NSMutableData!
    var expectedSize : Int!
    
    var delegate : CBImageFetchRequestDelegate!
    var con : NSURLConnection?
    
    init(imageURL: String!, completion: CBImageFetchCallback!, progress: CBProgressBlock? ) {
        super.init()
        
        baseURL = imageURL
        completionBlocks = [completion]
        if progress != nil { progressBlocks = [progress!] }
    }
    
    func start() {
        var url = NSURL(string: baseURL)
        if url == nil {
            var err = NSError(domain: "CBToolkit", code: 100, userInfo: [NSLocalizedDescriptionKey: "Invalid url for image download"])
            for cBlock in completionBlocks {
                cBlock(image: nil, error: err)
            }
            self.delegate.fetchRequestDidFinish(baseURL, image: nil)
            return
        }
        
        var request = NSMutableURLRequest(URL: url!, cachePolicy: NSURLRequestCachePolicy.ReturnCacheDataElseLoad, timeoutInterval: 30)
        request.HTTPMethod = "GET"
        con = NSURLConnection(request: request, delegate: self, startImmediately: false)
        con!.start()
    }
    
    func cancelRequest() {
        if con != nil {
            con!.cancel()
        }
    }
    
    func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        for cBlock in completionBlocks {
            cBlock(image: nil, error: error)
        }
        delegate.fetchRequestDidFinish(baseURL, image: nil)
    }
    
    
    func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        imgData.appendData(data)
        var progress = Float(imgData.length) / Float(expectedSize)
        
        for pBlock in progressBlocks {
            pBlock(progress: progress)
        }
    }
    
    
    func connectionDidFinishLoading(connection: NSURLConnection) {
        
        var img = UIImage(data: imgData)
        var error : NSError? = nil
        if img == nil {
            error = NSError(domain: "CBToolkit", code: 2, userInfo: [NSLocalizedDescriptionKey : "Could not procress image data into image."])
        }
        for cBlock in completionBlocks {
            cBlock(image: img, error: error)
        }
        delegate.fetchRequestDidFinish(baseURL, image: img)
    }
    
    func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse) {
        var res = response as! NSHTTPURLResponse
        var lengthStr = res.allHeaderFields["Content-Length"] as! String
        
        var numFormatter = NSNumberFormatter()
        expectedSize = numFormatter.numberFromString(lengthStr)!.unsignedIntegerValue
        imgData = NSMutableData(capacity: expectedSize)
        
    }
    
    
    
    
}






