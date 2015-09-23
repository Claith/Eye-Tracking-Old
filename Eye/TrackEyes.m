function [ Eyes ] = TrackEyes( NumberOfFrames, Prefix, Fileformat, FrameUpdate)
%TrackEyes Tracks eye movement across multiple frames
%   After the initial locating of the eyes, FindFaces uses the last
%   position of the eyes to find the closest region.

close all;

%constants
%CIE-lab minimum tone
Pmin = [5.2462, 15.4459, 31.3839];
%CIE-lab maximum tone
Pmax = [77.7485, 63.4912, 57.1265];
%PCA space
PCAM = [0.836141 0.307689 0.454089;
    -0.376524 -0.2800377 0.883068;
    -0.398871 0.909344 0.118298];

Eyes = cell([NumberOfFrames 2]); %First value is the pairs of eyes, second is the size

EyePair = zeros([5 4]); %[<Right Eye 1> <Left Eye 1>; <Right Eye 2> <Left Eye 2>;]
%may want to include a 5th field to track how long it has been since either
%possible Eye has been seen.

%for the sake of speed, I will assume that the eyes are found on the first
%frame. They are for the sample set afterall. I beleive frame 3 in the
%sample set does not find the left eye.

for num = 1:NumberOfFrames
     if num < 10 
        Image = imread(strcat(Prefix,'00',num2str(num),'.',Fileformat));
     else
        if num<100
            Image = imread(strcat(Prefix,'0',num2str(num),'.',Fileformat));
        else
            Image = imread(strcat(Prefix,num2str(num),'.',Fileformat));
        end
     end

[M N ~] = size(Image);

EyeCount = 0;

Im = false([M N]);

%identify skin (BW image) --- skin = black, non-skin = white
%locate skin tones

NImage = RGB2Lab(Image); %I was changing the image constantly... /sigh

for x=1:M
    for y=1:N
        tempColor = [NImage(x, y, 1) NImage(x, y, 2) NImage(x, y, 3)] * PCAM;
        if MinMaxLab(tempColor, Pmin, Pmax) ~= 1
            Im(x, y) = 0;
        else
            Im(x, y) = 1;
        end
    end
end

clear x y tempColor NImage;

Im = bwmorph(Im, 'bridge');

RegionCount = 0;

[B,L,N] = bwboundaries(Im(:,:));

RegionList = cell(length(B), 3);

if (FrameUpdate > 0) && (0 == mod(num, FrameUpdate))
    figure;
    imshow(Image);
    hold on;
end

for k=1:length(B),
    boundary = B{k};
    if(k > N) %after inverting the image, keep only the holes
        if size(boundary, 1) > 8 %remove noise. This will only work if the faces are large enough
            RegionCount = RegionCount + 1;
            RegionList{RegionCount, 1} = boundary(:, :);
            RegionList{RegionCount, 2} = k;
            RegionList{RegionCount, 3} = length(boundary);
            
            if (FrameUpdate > 0) && (0 == mod(num, FrameUpdate))
                 plot(boundary(:,2),...
                     boundary(:,1),'g','LineWidth',2);
            end
        end
    end
end

clear k;

RegionList = RegionList(1:RegionCount, :); %trimmed off the fat.

RegionList = sortrows(RegionList, -3);

%rebuild cell array into normal array.. gotta curb this issue for
%comparison

IndexList = cell2mat(RegionList(:, 2));
SizeList = cell2mat(RegionList(:, 3));
UniqueRegionList = [];
for i=1:RegionCount %I am sure there is an easier way to do this, but lack of experience continues to bite
    temp = RegionList{i, 1};
    UniqueRegionList = cat(1, UniqueRegionList, [temp(1,1) temp(1,2)]);
    %assuming all points are unique, just getting 1 value from this list should be good.
end
IndexList = cat(2, IndexList, SizeList); %multiple lines for debugging
UniqueRegionList = cat(2,UniqueRegionList, IndexList);
%<x-coord>, <y-coord>, <L-Index>, <Size>

SearchRange = zeros([M 2]);
SearchRange(:, 2) = 1:M; %lay down the x-coord of the points to search

i = 1;
EyesSet = false([RegionCount 1]);
EyePairsSet = 0;
while (i<=RegionCount) && (EyePairsSet == 0)
    
    EyesSet(i) = true;
    EyePairsSet = 0;
    
    if num ~= 1 %changing to frame number
        EyePair = cell2mat(Eyes(num-1));
        
        while EyeCount < Eyes{num-1, 2}
            EyeCount = EyeCount + 1;
        
            %Search for Right Eye
            Overlap = L(floor(EyePair(EyeCount, 2)), floor(EyePair(EyeCount, 1)));

            [TF Ind] = ismember(Overlap, UniqueRegionList(:,3));

            if TF
                %if the point that the last pair of eyes were found have an
                %index, then use that region as the new eye
                
                EyePair(EyeCount, 2) = 0;
                EyePair(EyeCount, 1) = 0;

                for t=1:RegionList{Ind, 3}
                    EyePair(EyeCount, 2) = EyePair(EyeCount, 2) + RegionList{Ind, 1}(t, 1);
                    EyePair(EyeCount, 1) = EyePair(EyeCount, 1) + RegionList{Ind, 1}(t, 2);
                end
                
                EyePair(EyeCount, 1) = EyePair(EyeCount, 1) / RegionList{Ind, 3};
                EyePair(EyeCount, 2) = EyePair(EyeCount, 2) / RegionList{Ind, 3};
            end

            %Search for Left Eye
            Overlap = L(floor(EyePair(EyeCount,4)), floor(EyePair(EyeCount,3)));

            [TF Ind] = ismember(Overlap, UniqueRegionList(:,3));
            if TF                
                EyePair(EyeCount, 4) = 0;
                EyePair(EyeCount, 3) = 0;

                for t=1:RegionList{Ind, 3}
                    EyePair(EyeCount, 4) = EyePair(EyeCount, 4) + RegionList{Ind, 1}(t, 1);
                    EyePair(EyeCount, 3) = EyePair(EyeCount, 3) + RegionList{Ind, 1}(t, 2);
                end

                EyePair(EyeCount, 3) = EyePair(EyeCount, 3)./RegionList{Ind, 3};
                EyePair(EyeCount, 4) = EyePair(EyeCount, 4)./RegionList{Ind, 3};
            end

            %draw eye
            if (FrameUpdate > 0) && (0 == mod(num, FrameUpdate))
                line(EyePair(EyeCount, 1), EyePair(EyeCount, 2), 'Color', 'r', 'Marker', 'o', 'MarkerSize', 10);
                line(EyePair(EyeCount, 3), EyePair(EyeCount, 4), 'Color', 'r', 'Marker', 'o', 'MarkerSize', 10);
            end
        end %end of eye pair loop
        
        Eyes{num, 1} = EyePair;
        Eyes{num, 2} = EyeCount;
        EyePairsSet = 1;
        
    else %if the Eyes are not set
    
    x = 0;
    y = 0;

    for t=1:RegionList{i, 3}
        x = x + RegionList{i, 1}(t, 1);
        y = y + RegionList{i, 1}(t, 2);
    end
    
    x = x./RegionList{i, 3};
    y = y./RegionList{i, 3};
    
    MatchingEye = 0;
    
    for r=1:M
        SearchRange(r, 1) = floor(x);
    end
    
    h=i+1;
    while (h<=RegionCount) && (MatchingEye == 0) && ~EyesSet(h)
        %don't want to include the same regions in multiple eye pairs,
        %could always purge the results I suppose, if this does not work.
        %this method seems to work well right now. So currently I need to
        %track all eye pairs and add in a frame tolerance to decide if I
        %should drop a pair or not.
        SearchRegion = RegionList{h, 1};
        
        %from test data: Frame #1:- 1:Left-Eye 2:Mouth 3:Right-Eye 4: 5:Nose
        
        BestMatch = Inf;
        
        for R=1:length(SearchRegion) %this may not be faster, but I find it more predictable
            if SearchRange(SearchRegion(R, 1), 1) == SearchRegion(R, 1)
                
                if MatchingEye == 0
                    MatchingEye = h;
                    BestMatch = abs(RegionList{i, 3} - RegionList{MatchingEye, 3}) / RegionList{i, 3};
                else
                    %search for best match based on size of region.
                    NewMatch = abs(RegionList{i, 3} - RegionList{MatchingEye, 3}) / RegionList{i, 3};
                    if NewMatch < BestMatch
                        MatchingEye = h;
                        BestMatch = NewMatch; %I suppose I could keep track of all possible pairs of eyes
                        %If both eyes disappear for a given length of time,
                        %I could remove that pair from being tracked.
                    end
                end
            end
        end
        
        h=h+1;
    end
    
        
    if MatchingEye > 0
        
        EyesSet(MatchingEye) = true;
        EyeCount = EyeCount + 1;
        
        Mx = 0;
        My = 0;
        
        %average the matching eye
        for t=1:RegionList{MatchingEye, 3}
            Mx = Mx + RegionList{MatchingEye, 1}(t, 1);
            My = My + RegionList{MatchingEye, 1}(t, 2);
        end

        Mx = Mx./RegionList{MatchingEye, 3};
        My = My./RegionList{MatchingEye, 3};
        
        if (FrameUpdate > 0) && (0 == mod(num, FrameUpdate))
            line(y, x, 'Color', 'r', 'Marker', 'o', 'MarkerSize', 10);
            line(My, Mx, 'Color', 'r', 'Marker', 'o', 'MarkerSize', 10);
        %hold off;
        end
        
        %log Eye information here.
        if floor(y)<floor(My) %if the first region found is less than the second region, then it is the right eye
            EyePair(EyeCount, 1) = y;
            EyePair(EyeCount, 2) = x;
            EyePair(EyeCount, 3) = My;
            EyePair(EyeCount, 4) = Mx;
        else
            EyePair(EyeCount, 1) = My;
            EyePair(EyeCount, 2) = Mx;
            EyePair(EyeCount, 3) = y;
            EyePair(EyeCount, 4) = x;
        end
        
        Eyes{num, 1} = EyePair;
        Eyes{num, 2} = EyeCount;
        
    end
    
    end %end of if Eyes found conditional
    
    i=i+1;
end

Eyes{num, 1} = Eyes{num, 1}(1:EyeCount, :); %removing extras
%One of the issues to removing bad possible eyes, is that after every loop
%the Eyes will lose their synchronization unless I take further measures. I
%don't feel like taking those measures currently.

clear h i MatchingEye Mx My x y B N M L;
clear RegionList UniqueRegionList IndexList SizeList Im;
clear SearchRange SearchRegion;
clear EyePair EyeCount EyesSet;

end %end of per frame loop

clear num;

%At this point, draw a line connecting all of the eye markers together.
figure;
imshow(Image);
hold on;
for e=1:NumberOfFrames
    EyeCount = 0;
    EyePair = cell2mat(Eyes(e));
    
    while EyeCount < Eyes{e, 2}
        EyeCount = EyeCount + 1;
        if e == 1 %display markers
            line(EyePair(EyeCount, 1), EyePair(EyeCount, 2), 'Color', 'r', 'Marker', 'o', 'MarkerSize', 10);
            line(EyePair(EyeCount, 3), EyePair(EyeCount, 4), 'Color', 'g', 'Marker', 'o', 'MarkerSize', 10);
        else %draw lines, does not consider dead eyes yet
            line([EyePair(EyeCount, 1) LastPair(EyeCount, 1)], [EyePair(EyeCount, 2) LastPair(EyeCount, 2)], 'Color', 'r', 'LineWidth', 2);
            line([EyePair(EyeCount, 3) LastPair(EyeCount, 3)], [EyePair(EyeCount, 4) LastPair(EyeCount, 4)], 'Color', 'g', 'LineWidth', 2);
        end
    end
    
    LastPair = EyePair; %need to track the last pair of eyes
end

%draw the last markers
EyePair = cell2mat(Eyes(NumberOfFrames));
EyeCount = 1;
while EyeCount <= Eyes{NumberOfFrames, 2} %this is a better form of the loops I have been using.
    line(EyePair(EyeCount, 1), EyePair(EyeCount, 2), 'Color', 'r', 'Marker', 'o', 'MarkerSize', 10);
    line(EyePair(EyeCount, 3), EyePair(EyeCount, 4), 'Color', 'g', 'Marker', 'o', 'MarkerSize', 10);
    EyeCount = EyeCount + 1;
end

hold off;

clear e Image;

end %end of function again
