{-# Language ScopedTypeVariables, EmptyDataDecls #-}
module Data.Bond.SimpleBinaryProto (
        SimpleBinaryV1Proto,
        SimpleBinaryProto
    ) where

import Data.Bond.Cast
import Data.Bond.Monads
import Data.Bond.Proto
import Data.Bond.Types
import Data.Bond.Utils

import Control.Applicative
import Control.Monad
import Data.List
import Data.Maybe
import Prelude          -- ghc 7.10 workaround for Control.Applicative

import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BL
import qualified Data.HashSet as H
import qualified Data.Map as M
import qualified Data.Set as S
import qualified Data.Vector as V

data SimpleBinaryV1Proto
data SimpleBinaryProto

instance BondProto SimpleBinaryProto where
    bondGetStruct = bondStructGetUntagged
    bondGetBaseStruct = bondStructGetUntagged

    bondGetBool = do
        v <- getWord8
        return $ v /= 0
    bondGetUInt8 = getWord8
    bondGetUInt16 = getWord16le
    bondGetUInt32 = getWord32le
    bondGetUInt64 = getWord64le
    bondGetInt8 = fromIntegral <$> getWord8
    bondGetInt16 = fromIntegral <$> getWord16le
    bondGetInt32 = fromIntegral <$> getWord32le
    bondGetInt64 = fromIntegral <$> getWord64le
    bondGetFloat = wordToFloat <$> getWord32le
    bondGetDouble = wordToDouble <$> getWord64le
    bondGetString = do
        n <- getVarInt
        Utf8 <$> getByteString (fromIntegral n)
    bondGetWString = do
        n <- getVarInt
        Utf16 <$> getByteString (fromIntegral $ n * 2)
    bondGetBlob = do
        n <- getVarInt
        Blob <$> getByteString (fromIntegral n)
    bondGetDefNothing = Just <$> bondGet
    bondGetList = do
        n <- getVarInt
        replicateM n bondGet
    bondGetHashSet = H.fromList <$> bondGetList
    bondGetSet = S.fromList <$> bondGetList
    bondGetMap = do
        n <- getVarInt
        fmap M.fromList $ replicateM n $ liftM2 (,) bondGet bondGet
    bondGetVector = V.fromList <$> bondGetList
    bondGetNullable = do
        v <- bondGetList
        case v of
            [] -> return Nothing
            [x] -> return (Just x)
            _ -> fail $ "list of length " ++ show (length v) ++ " where nullable expected"
    bondGetBonded = do
        size <- getWord32le
--        sig <- BondGet getWord32be
        bs <- getLazyByteString (fromIntegral size)
        return $ BondedStream bs

    bondPutStruct = bondStructPut
    bondPutBaseStruct = bondStructPut
    bondPutField _ = bondPut
    bondPutDefNothingField _ Nothing = fail "can't save empty \"default nothing\" field with untagged protocol"
    bondPutDefNothingField _ (Just v) = bondPut v

    bondPutBool True = putWord8 1
    bondPutBool False = putWord8 0
    bondPutUInt8 = putWord8
    bondPutUInt16 = putWord16le
    bondPutUInt32 = putWord32le
    bondPutUInt64 = putWord64le
    bondPutInt8 = putWord8 . fromIntegral
    bondPutInt16 = putWord16le . fromIntegral
    bondPutInt32 = putWord32le . fromIntegral
    bondPutInt64 = putWord64le . fromIntegral
    bondPutFloat = putWord32le . floatToWord
    bondPutDouble = putWord64le . doubleToWord
    bondPutString (Utf8 s) = do
        putVarInt $ BS.length s
        putByteString s
    bondPutWString (Utf16 s) = do
        putVarInt $ BS.length s `div` 2
        putByteString s
    bondPutList xs = do
        putVarInt $ length xs
        mapM_ bondPut xs
    bondPutNullable = bondPutList . maybeToList
    bondPutHashSet = bondPutList . H.toList
    bondPutSet = bondPutList . S.toList
    bondPutMap m = do
        putVarInt $ M.size m
        forM_ (M.toList m) $ \(k, v) -> do
            bondPut k
            bondPut v
    bondPutVector xs = do
        putVarInt $ V.length xs
        V.mapM_ bondPut xs
    bondPutBlob (Blob b) = do
        putVarInt $ BS.length b
        putByteString b
    bondPutBonded (BondedObject _) = undefined
    bondPutBonded (BondedStream s) = do
        putWord32le $ fromIntegral $ BL.length s
        putLazyByteString s
